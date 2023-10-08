#!/bin/bash

(
  until dockerd-entrypoint.sh; do
    echo Failed to start Docker Daemon. Retrying in 5 seconds...
    sleep 5
  done
) &

(su nonroot -c start.sh) &

wait
