# Environment for eval runs: the two CLIs are pinned (Debian packages and plugins are not); nothing from the host is mounted.
# Build: docker build -t ahr-eval:base --target base eval/
#        docker build -t ahr-eval:machine --target machine eval/
FROM debian:stable-slim AS base
ARG CLAUDE_VERSION=2.1.288
ARG CODEX_VERSION=0.160.0
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git python3 python3-venv nodejs npm perl jq procps \
    && rm -rf /var/lib/apt/lists/* \
    && echo 'export PATH="/home/dev/.local/bin:/home/dev/.npm-global/bin:$PATH"' > /etc/profile.d/dev-path.sh
RUN useradd -m -s /bin/bash dev
USER dev
WORKDIR /home/dev
ENV PATH="/home/dev/.local/bin:/home/dev/.npm-global/bin:${PATH}" \
    NPM_CONFIG_PREFIX=/home/dev/.npm-global \
    DISABLE_AUTOUPDATER=1
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_VERSION}" \
    && npm install -g "@openai/codex@${CODEX_VERSION}" \
    && claude --version && codex --version
RUN git config --global user.name eval && git config --global user.email eval@example.invalid \
    && git config --global init.defaultBranch main

# "Like the maintainer's machine": the plugins this config routes to, without host hooks or proxies.
FROM base AS machine
RUN claude plugin marketplace add obra/superpowers-marketplace \
    && claude plugin install superpowers@superpowers-marketplace \
    && claude plugin marketplace add openai/codex-plugin-cc \
    && claude plugin install codex@openai-codex \
    && claude plugin marketplace add DietrichGebert/ponytail \
    && claude plugin install ponytail@ponytail \
    && claude plugin marketplace add JuliusBrussee/caveman \
    && claude plugin install caveman@caveman \
    && claude plugin list
RUN codex plugin marketplace add obra/superpowers-marketplace \
    && codex plugin add superpowers@superpowers-marketplace \
    && codex plugin marketplace add DietrichGebert/ponytail \
    && codex plugin add ponytail@ponytail \
    && codex plugin list
