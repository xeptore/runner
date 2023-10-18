#!/bin/bash

set -ux

(
  sleep 5
  until dockerd-entrypoint.sh; do
    echo 'Failed to start Docker Daemon. Retrying in 5 seconds...'
    sleep 5
  done
) &

dockerd_pid=$!

(su nonroot -c start.sh)

kill -SIGINT $dockerd_pid

wait -n $dockerd_pid

sleep 3
