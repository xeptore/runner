# syntax=docker/dockerfile:1
FROM docker.io/library/ubuntu:23.04
ARG RUNNER_VERSION
RUN <<eot
  set -eux
  apt-get update
  apt-get upgrade -y
  apt-get install -y --no-install-recommends --no-install-suggests \
  apt-transport-https \
  build-essential \
  bzip2 \
  ca-certificates \
  cgroup-lite \
  cgroup-tools \
  cgroupfs-mount \
  curl \
  debian-archive-keyring \
  debian-keyring \
  diceware \
  fuse-overlayfs \
  gcc \
  git \
  gnupg \
  iproute2 \
  iptables \
  jq \
  kmod \
  libffi-dev \
  libssl-dev \
  make \
  net-tools \
  nethogs \
  openssh-client \
  openssl \
  perl \
  pigz \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  tar \
  uidmap \
  unzip \
  wget \
  xz-utils
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y --no-install-recommends --no-install-suggests docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  apt-get autoremove -y
  apt-get autoclean -y
  rm -rf /var/lib/apt/lists/*
  useradd -m -s /bin/bash -G docker nonroot
  (
    su nonroot
    cd /home/nonroot
    mkdir actions-runner
    cd actions-runner
    curl -sSfL https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz | tar -xzvf -
  )
  bash /home/nonroot/actions-runner/bin/installdependencies.sh
  mkdir /certs /certs/client && chmod 1777 /certs /certs/client
eot
ENV DOCKER_TLS_CERTDIR=/certs
COPY \
  --from=docker.io/library/docker:dind \
  --chown=root:root \
  /usr/local/bin/modprobe \
  /usr/local/bin/dockerd-entrypoint.sh \
  /usr/local/bin/docker-entrypoint.sh \
  /usr/local/bin/
COPY entrypoint.sh start.sh /usr/local/bin/
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
VOLUME /var/lib/docker
WORKDIR /home/nonroot/actions-runner
ENTRYPOINT ["entrypoint.sh"]
