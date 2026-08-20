# Source: https://github.com/actions/runner/blob/main/images/Dockerfile
FROM ghcr.io/actions/actions-runner:2.336.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DOTNET_INSTALL_DIR=./.dotnet
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV GITHUB_HOST=github.com
ENV NVM_DIR=/home/runner/.nvm
ENV PATH=/usr/local/go/bin:$PATH
ENV KUBECTL_VERSION=v1.36.3
ENV HELM_VERSION=v4.2.3
ENV GO_VERSION=1.26.5

RUN sudo apt update -y \
    && sudo apt install -y --no-install-recommends ca-certificates curl gnupg lsb-release software-properties-common \
    && sudo add-apt-repository --yes --update ppa:ansible/ansible \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt update -y \
    && sudo apt install -y --no-install-recommends ansible ovmf qemu-system-x86 qemu-utils terraform \
    && KUBERNETES_ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBERNETES_ARCH}/kubectl" \
    && sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl \
    && rm /tmp/kubectl \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${KUBERNETES_ARCH}.tar.gz" | sudo tar -C /tmp -xz \
    && sudo install -m 0755 "/tmp/linux-${KUBERNETES_ARCH}/helm" /usr/local/bin/helm \
    && rm -rf "/tmp/linux-${KUBERNETES_ARCH}" \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | sudo tar -C /usr/local -xz \
    && sudo apt install -y --no-install-recommends p7zip-full clang cmake zlib1g-dev python3 python3-venv python3-pip jq gettext-base libfontconfig1 libnspr4 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxkbcommon0 libasound2t64 libgbm1 libcairo2 libpango-1.0-0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libatspi2.0-0t64 \
    && sudo python3 -m pip install --break-system-packages --ignore-installed awscli kubernetes \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash \
    && source "$NVM_DIR/nvm.sh" \
    && nvm install 24 \
    && nvm alias default 24 \
    && sudo ln -s "$(command -v node)" /usr/local/bin/node \
    && sudo ln -s "$(command -v npm)" /usr/local/bin/npm \
    && sudo ln -s "$(command -v npx)" /usr/local/bin/npx \
    && sudo ln -s /usr/bin/pip3 /usr/local/bin/pip \
    && sudo rm -rf /var/lib/apt/lists/*

# Support for Playwright
RUN npx -y playwright install chromium \
    && if [ "$(arch)" = "x86_64" ]; then \
        npx -y playwright install chrome; \
    fi
