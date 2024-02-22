#!/bin/bash

bail() {
  printf 'Error executing command, exiting'
  exit 1
}

exec_cmd_nobail() {
  printf '\n%s$ %s\n\n' "$(pwd)" "$1"
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
  /root/sing-box/sing-box run -c /root/sing-box/config.json &
  singbox_pid=$!
  sleep 2
  /root/sing-box/iptables-set.sh
  trap "kill -SIGINT $singbox_pid" INT
fi

(
  until dockerd-entrypoint.sh; do
    echo 'Failed to start Docker Daemon. Retrying in 2 seconds...'
    sleep 2
  done
) &
dockerd_entrypoint_pid=$!

su nonroot -c start.sh &
start_pid=$!
trap 'kill -SIGINT $start_pid; kill -SIGINT "$(cat /var/run/docker.pid)"' HUP INT QUIT TERM ABRT

wait -fn $start_pid
wait -fn $dockerd_entrypoint_pid

sleep 3
