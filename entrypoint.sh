#!/bin/bash

# https://stackoverflow.com/a/46829294
set -m

declare -a on_trap
handle_trap() {
  length=${#on_trap[@]}
  if [[ length -eq 0 ]]; then
    return 0
  fi

  echo '> Running shutdown procedure...'

  declare -a reversed
  for ((i = length - 1; i >= 0; i--)); do
    # https://stackoverflow.com/q/1951506
    reversed+=("${on_trap[i]}")
    unset "on_trap[i]"
  done

  # https://www.cyberciti.biz/faq/bash-for-loop-array/
  for cmd in "${reversed[@]}"; do
    # https://stackoverflow.com/questions/1951506/add-a-new-element-to-an-array-without-specifying-the-index-in-bash
    # https://phoenixnap.com/kb/bash-eval
    eval "$cmd"
  done

  echo '> Finished shutdown procedure.'
}

trap 'handle_trap' EXIT HUP INT QUIT TERM ABRT

printf "\n\n> Starting up on host %s...\n" "$(hostname)"

if [[ -n "${REGISTRY_MIRRORS}" ]]; then
  echo "> Configuring Docker registry mirrors with ${REGISTRY_MIRRORS}..."
  echo "${REGISTRY_MIRRORS}" | jq -R '{"registry-mirrors": split(",")}' >/etc/docker/daemon.json
  echo '> Docker registry mirrors configured.'
fi

if [[ -n "${PROXY_SOCKS_HOST}" && -n "${PROXY_SOCKS_PORT}" ]]; then
  echo '> Activating proxy client...'
  jq \
    --arg proxy_host "$PROXY_SOCKS_HOST" \
    --arg proxy_port "$PROXY_SOCKS_PORT" \
    --arg proxy_user "$PROXY_SOCKS_USER" \
    --arg proxy_pass "$PROXY_SOCKS_PASS" \
    '.outbounds[0] += {server: $proxy_host, server_port: ($proxy_port | tonumber), username: $proxy_user, password: $proxy_pass}' \
    /root/sing-box/config.template.json >/root/sing-box/config.json

  echo '> Spawning proxy client...'
  /root/sing-box/sing-box run -c /root/sing-box/config.json &
  singbox_pid=$!
  close_singbox() {
    echo '> Shutting down proxy client...'
    kill -INT "$singbox_pid" && wait -fn "$singbox_pid"
    echo '> Proxy client is shutdown.'
  }
  on_trap+=(close_singbox)
  echo "> Proxy client spawned in the backgroung with pid $singbox_pid"

  max_retries=10
  attempt=1
  while ((attempt <= max_retries)); do
    if ! (cat /sys/class/net/tun0/operstate >/dev/null 2>&1); then
      echo '> Proxy tunnel device is not ready yet. Retrying in 1 second...'
      sleep 1
      attempt=$((attempt + 1))
    else
      echo '> Proxy tunnel device is ready.'
      break
    fi
  done
  if [[ attempt -gt max_retries ]]; then
    echo "> Failed to wait for proxy tunnel device to become ready after $attempt retries."
    exit 69
  fi

  /root/sing-box/iptables-set.sh
fi

reg_token=$(curl -1sSfLX POST -H 'Accept: application/vnd.github+json' -H "Authorization: Bearer ${ACCESS_TOKEN}" -H 'X-GitHub-Api-Version: 2022-11-28' "https://api.github.com/repos/${REPO}/actions/runners/registration-token" | jq .token --raw-output)

echo '> Registering runner...'
su nonroot -c "./config.sh --unattended --url https://github.com/${REPO} --token ${reg_token} --ephemeral --labels self-hosted --replace --name $(hostname)"
echo '> Runner registered.'

clear_runner() (
  set -eEuo pipfail
  echo '> Running runner cleanup...'
  echo '> Obtaining runner remove token...'
  remove_token=$(curl -1sSfLX POST -H 'Accept: application/vnd.github+json' -H "Authorization: Bearer ${ACCESS_TOKEN}" -H 'X-GitHub-Api-Version: 2022-11-28' "https://api.github.com/repos/${REPO}/actions/runners/remove-token" | jq .token --raw-output)
  echo '> Obtained runner remove token.'
  echo '> Removing the runner...'
  su nonroot -c "./config.sh remove --token ${remove_token}"
  echo '> Runner removed.'
  echo '> Running runner cleanup done.'
)
on_trap+=(clear_runner)

(
  max_retries=10
  attempt=1
  while ((attempt <= max_retries)); do
    if ! dockerd-entrypoint.sh; then
      echo '> Failed to start Docker Daemon. Retrying in 2 seconds...'
      sleep 2
      attempt=$((attempt + 1))
    else
      break
    fi
  done
  if [[ attempt -gt max_retries ]]; then
    echo "> Failed to start Docker Daemon after $attempt retries."
    exit 69
  fi
) &
dockerd_entrypoint_pid=$!

stop_docker_daemon() {
  echo '> Shutting Docker Daemon down...'
  [[ -f /var/run/docker.pid ]] && kill -INT "$(cat /var/run/docker.pid)" && wait -fn $dockerd_entrypoint_pid
  echo '> Docker Daemon shutdown.'
}
on_trap+=(stop_docker_daemon)

(
  command='docker info >/dev/null 2>&1'
  max_retries=20
  attempt=1
  while ((attempt <= max_retries)); do
    if ! eval "$command"; then
      echo '> Docker Daemon is not yet ready. Retrying in 1 second...'
      sleep 1
      attempt=$((attempt + 1))
    else
      break
    fi
  done
  if [[ attempt -gt max_retries ]]; then
    echo "> Failed to wait for Docker Daemon to become ready after $attempt retries."
    exit 69
  fi
)

echo '> Spawning runner...'
su nonroot -c ./run.sh &
runner_pid=$!
echo "> Runner spawned with pid $runner_pid."

stop_runner() {
  echo '> Shuting down runner...'
  local runner_listener_pid
  runner_listener_pid=$(pidof -s Runner.Listener)
  [[ -n "${runner_listener_pid}" ]] && echo "> Stopping runner with listener pid $runner_listener_pid" && kill -INT "$runner_listener_pid"
  wait -fn $runner_pid
  echo '> Runner shutdown.'
}
on_trap+=(stop_runner)

wait -fn $runner_pid
