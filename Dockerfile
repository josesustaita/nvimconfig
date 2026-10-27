FROM golang:1.25-bookworm AS go
FROM rust:1.90-slim-bookworm AS rust
FROM node:22-bookworm-slim
ARG NVIM_VERSION=v0.11.5
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends git curl ca-certificates build-essential ripgrep fd-find unzip python3 python3-venv && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && case "$TARGETARCH" in amd64) arch=x86_64 ;; arm64) arch=arm64 ;; *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; esac \
    && curl -fL --retry 3 "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${arch}.tar.gz" | tar -xz --strip-components=1 -C /usr/local \
    && npm install -g tree-sitter-cli
COPY --from=go /usr/local/go /usr/local/go
COPY --from=rust --chown=node:node /usr/local/cargo /usr/local/cargo
COPY --from=rust --chown=node:node /usr/local/rustup /usr/local/rustup
ENV PATH="/usr/local/go/bin:/usr/local/cargo/bin:${PATH}" CARGO_HOME=/usr/local/cargo RUSTUP_HOME=/usr/local/rustup
USER node
WORKDIR /home/node
COPY --chown=node:node init.lua lazyvim.json lazy-lock.json /home/node/.config/nvim/
COPY --chown=node:node lua /home/node/.config/nvim/lua
COPY --chown=node:node scripts/check.lua scripts/provision.lua /home/node/.config/nvim/scripts/
ENV XDG_CONFIG_HOME=/home/node/.config XDG_DATA_HOME=/home/node/.local/share XDG_STATE_HOME=/home/node/.local/state XDG_CACHE_HOME=/home/node/.cache TERM=xterm-256color
RUN NVIM_REDUCED_MOTION=1 nvim --headless '+Lazy! restore' '+lua dofile(vim.fn.stdpath("config") .. "/scripts/provision.lua")' 
WORKDIR /workspace
ENTRYPOINT ["nvim"]
