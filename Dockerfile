# Source: https://github.com/actions/runner/blob/main/images/Dockerfile
FROM ghcr.io/actions/actions-runner:2.336.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DOTNET_INSTALL_DIR=./.dotnet
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV GITHUB_HOST=github.com
ENV NVM_DIR=/home/runner/.nvm
ENV PATH=/home/runner/.nvm/versions/node/v24.18.1/bin:$PATH

RUN sudo apt update -y \
    && sudo apt install -y --no-install-recommends ca-certificates curl \
    && sudo apt install -y --no-install-recommends p7zip-full clang cmake zlib1g-dev python3 python3-venv python3-pip jq gettext-base libfontconfig1 libnspr4 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxkbcommon0 libasound2t64 libgbm1 libcairo2 libpango-1.0-0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libatspi2.0-0t64 \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash \
    && source "$NVM_DIR/nvm.sh" \
    && nvm install 24 \
    && nvm alias default 24 \
    && sudo ln -s /usr/bin/pip3 /usr/local/bin/pip \
    && sudo rm -rf /var/lib/apt/lists/*

# Support for Playwright
RUN npx -y playwright install chromium \
    && if [ "$(arch)" = "x86_64" ]; then \
        npx -y playwright install chrome; \
    fi
