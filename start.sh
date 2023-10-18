#!/bin/bash

until (docker info >/dev/null 2>&1); do
  echo 'Waiting for Docker Daemon to become ready...'
  sleep 3
done

set -eu

REG_TOKEN=$(curl -sLX POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/${REPO}/actions/runners/registration-token" | jq .token --raw-output)

./config.sh --unattended --url "https://github.com/${REPO}" --token "${REG_TOKEN}" --ephemeral --labels self-hosted --replace --name "$(hostname)"

cleanup() {
  echo "Removing runner..."
  ./config.sh remove --token "${REG_TOKEN}"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh
