#!/bin/bash

set -Eeuo pipefail

if [[ -n "${PROXY_SOCKS_HOST}" && -n "${PROXY_SOCKS_PORT}" ]]; then
  jq \
    --arg proxy_host "$PROXY_SOCKS_HOST" \
    --arg proxy_port "$PROXY_SOCKS_PORT" \
    '.outbounds[0].settings.servers[0] += {address: $proxy_host, port: ($proxy_port | tonumber)}' \
    /root/xray/config.template.json > /root/xray/config.json
  /root/xray/iptables-set.sh
  /root/xray/xray -c /root/xray/config.json &
  xray_pid=$1
  trap "kill -SIGINT $xray_pid" INT
fi

(
  sleep 5
  until dockerd-entrypoint.sh; do
    echo 'Failed to start Docker Daemon. Retrying in 5 seconds...'
    sleep 5
  done
) &

dockerd_entrypoint_pid=$!

su nonroot -c start.sh &

start_pid=$!

trap 'kill -SIGINT $start_pid; kill -SIGINT "$(cat /var/run/docker.pid)"' INT

wait -fn $start_pid

[[ -f /var/run/docker.pid ]] && kill -SIGINT "$(cat /var/run/docker.pid)"

wait -f $dockerd_entrypoint_pid

sleep 3
