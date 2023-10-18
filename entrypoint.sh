#!/bin/bash

set -u

(
  sleep 5
  until dockerd-entrypoint.sh; do
    echo 'Failed to start Docker Daemon. Retrying in 5 seconds...'
    sleep 5
  done
) &

dockerd_entrypoint_pid=$!

su nonroot -c start.sh

kill -SIGINT "$(cat /var/run/docker.pid)"

wait -fn $dockerd_entrypoint_pid

sleep 3
