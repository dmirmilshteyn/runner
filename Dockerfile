# Source: https://github.com/actions/runner/blob/main/images/Dockerfile
FROM ghcr.io/actions/actions-runner:2.334.0

ENV DOTNET_INSTALL_DIR=./.dotnet
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV GITHUB_HOST=github.com

RUN sudo apt update -y \
    && sudo apt install -y --no-install-recommends p7zip-full clang zlib1g-dev nodejs npm libfontconfig1 libnspr4 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxkbcommon0 libasound2t64 libgbm1 libcairo2 libpango-1.0-0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libatspi2.0-0t64 \
    && sudo rm -rf /var/lib/apt/lists/*

# Support for Playwright
RUN npx -y playwright install chromium \
    && npx -y playwright install chrome
