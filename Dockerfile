# syntax=docker/dockerfile:1
FROM docker.io/library/ubuntu:25.04
ARG RUNNER_VERSION
ARG SINGBOX_TAG=1.12.3-1
RUN <<EOT
#!/usr/bin/bash
set -Eeuo pipefail

# shellcheck disable=SC1090
source <(curl -fsSL --proto '=https' --tlsv1.3 https://gist.xeptore.dev/run.sh)

run 'apt-get update'
run 'apt-get upgrade -y'
run 'apt-get install -y --no-install-recommends --no-install-suggests software-properties-common'
run 'add-apt-repository ppa:git-core/ppa'
run 'apt-get purge -y software-properties-common'
run 'apt-get install -y --no-install-recommends --no-install-suggests \
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
  libicu76 \
  libicu-dev \
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
  xz-utils \
  zip'
run 'install -m 0755 -d /etc/apt/keyrings'
run 'curl -fsSL --tlsv1.3 https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
run 'chmod a+r /etc/apt/keyrings/docker.gpg'
run "echo \
  \"deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  \"$(. /etc/os-release && echo "$VERSION_CODENAME")\" stable\" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null"
run 'apt-get update'
run 'apt-get install -y --no-install-recommends --no-install-suggests docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
run 'apt-get autoremove -y'
run 'apt-get autoclean -y'
run 'rm -rf /var/lib/apt/lists/*'
run 'useradd -m -s /bin/bash -G docker nonroot'
su nonroot <<EOB
run 'cd /home/nonroot'
run 'mkdir actions-runner'
run 'cd actions-runner'
run "curl -SfL --tlsv1.3 https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz | tar -xzvf -"
EOB
run 'su nonroot <<EOB
bash /home/nonroot/actions-runner/bin/installdependencies.sh
EOB'
run 'mkdir /certs /certs/client && chmod 1777 /certs /certs/client'
run 'mkdir /root/sing-box'
run "curl -SfL --tlsv1.3 https://github.com/z4x7k/sing-box-all/releases/download/${SINGBOX_TAG}/sing-box -o /root/sing-box/sing-box && chmod +x /root/sing-box/sing-box"
EOT
ENV DOCKER_TLS_CERTDIR=/certs
COPY \
  --from=docker.io/library/docker:dind \
  --chown=root:root \
  /usr/local/bin/modprobe \
  /usr/local/bin/dockerd-entrypoint.sh \
  /usr/local/bin/docker-entrypoint.sh \
  /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/
COPY sing-box.json /root/sing-box/config.template.json
COPY iptables-set.sh /root/sing-box/iptables-set.sh
RUN chmod +x /root/sing-box/iptables-set.sh
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
VOLUME /var/lib/docker
WORKDIR /home/nonroot/actions-runner
STOPSIGNAL SIGINT
ENTRYPOINT ["entrypoint.sh"]
