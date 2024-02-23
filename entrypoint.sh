#!/bin/bash

bail() {
  printf 'Error executing command, exiting'
  exit 1
}

exec_cmd_nobail() {
  printf '\n%s# %s\n' "$(pwd)" "$1"
  bash -c "$1"
}

exec_cmd() {
  exec_cmd_nobail "$1" || bail
}

if [[ -n "${PROXY_SOCKS_HOST}" && -n "${PROXY_SOCKS_PORT}" ]]; then
  jq \
    --arg proxy_host "$PROXY_SOCKS_HOST" \
    --arg proxy_port "$PROXY_SOCKS_PORT" \
    --arg proxy_user "$PROXY_SOCKS_USER" \
    --arg proxy_pass "$PROXY_SOCKS_PASS" \
    '.outbounds[0] += {server: $proxy_host, server_port: ($proxy_port | tonumber), username: $proxy_user, password: $proxy_pass}' \
    /root/sing-box/config.template.json > /root/sing-box/config.json
  EOB
  exec_cmd '/root/sing-box/sing-box run -c /root/sing-box/config.json' &
  singbox_pid=$!
  sleep 2
  exec_cmd '/root/sing-box/iptables-set.sh'
  trap 'kill -INT $singbox_pid && wait -fn $singbox_pid' EXIT ERR HUP INT QUIT TERM ABRT
fi

REG_TOKEN=$(curl -sLX POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/${REPO}/actions/runners/registration-token" | jq .token --raw-output)

exec_cmd "su nonroot -c './config.sh --unattended --url https://github.com/${REPO} --token ${REG_TOKEN} --ephemeral --labels self-hosted --replace --name $(hostname)'"

cleanup() {
  echo 'Removing runner...'
  exec_cmd "su nonroot -c './config.sh remove --token ${REG_TOKEN}'"
}

trap cleanup EXIT ERR HUP INT QUIT TERM ABRT

(
  max_retries=10
  attempt=1
  while (( attempt <= max_retries )); do
    if ! dockerd-entrypoint.sh; then
      echo 'Failed to start Docker Daemon. Retrying in 2 seconds...'
      sleep 2
      attempt=$(( attempt + 1 ))
    else
      break
    fi
  done
  if [[ attempt -gt max_retries ]]; then
    echo "Failed to start Docker Daemon after $attempt retries."
    exit 69
  fi
) &
dockerd_entrypoint_pid=$!

trap '[[ -f /var/run/docker.pid ]] && kill -INT "$(cat /var/run/docker.pid)" && wait -fn $dockerd_entrypoint_pid' EXIT ERR HUP INT QUIT TERM ABRT

(
  command='docker info >/dev/null 2>&1'
  max_retries=20
  attempt=1
  while (( attempt <= max_retries )); do
    if ! eval "$command"; then
      echo 'Seems Docker Daemon is not yet ready. Retrying in 1 second...'
      sleep 1
      attempt=$(( attempt + 1 ))
    else
      break
    fi
  done
  if [[ attempt -gt max_retries ]]; then
    echo "Failed to wait for Docker Daemon after $attempt retries."
    exit 69
  fi
)

exec_cmd 'su nonroot -c ./run.sh'
cleanup

kill -INT "$(cat /var/run/docker.pid)" && wait -fn $dockerd_entrypoint_pid

if [[ -n "${singbox_pid}" ]]; then
  kill -INT "$singbox_pid" && wait -fn "$singbox_pid"
fi

sleep 1
