#!/bin/bash

set -Eeo pipefail

if [[ -n "${PROXY_SOCKS_HOST}" && -n "${PROXY_SOCKS_PORT}" ]]; then
  jq \
    --arg proxy_host "$PROXY_SOCKS_HOST" \
    --arg proxy_port "$PROXY_SOCKS_PORT" \
    '.outbounds[0].settings.servers[0] += {address: $proxy_host, port: ($proxy_port | tonumber)}' \
    /root/xray/config.template.json > /root/xray/config.json
  if [[ -n "${PROXY_SOCKS_USER}" ]]; then
    jq \
      --arg proxy_user "$PROXY_SOCKS_USER" \
      --arg proxy_pass "$PROXY_SOCKS_PASS" \
      '.outbounds[0].settings.servers[0] += { users: [{ user: $proxy_user, pass: $proxy_pass, level:0 }] }' \
      /root/xray/config.template.json > /root/xray/config.json
  fi
  /root/xray/iptables-set.sh
  /root/xray/xray -c /root/xray/config.json &
  xray_pid=$!
  trap "kill -SIGINT $xray_pid" INT
fi

su nonroot -c start.sh &
start_pid=$!
wait -fn $start_pid

(
  sleep 5
  until dockerd-entrypoint.sh; do
    echo 'Failed to start Docker Daemon. Retrying in 3 seconds...'
    sleep 3
  done
) &
dockerd_entrypoint_pid=$!
trap 'kill -SIGINT "$(cat /var/run/docker.pid)"' INT
wait -fn $dockerd_entrypoint_pid

sleep 3
