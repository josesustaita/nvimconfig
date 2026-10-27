#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "Start Docker with the Compose v2 plugin, then retry." >&2; exit 1
fi
case ${1:-} in
  doctor) docker compose config --quiet; echo "Docker is ready. Your host Neovim configuration stays untouched."; exit 0 ;;
  test) docker compose build; exec docker compose run --rm -T -e NVIM_REDUCED_MOTION=1 nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/scripts/check.lua")' ;;
  --help|-h) echo 'Usage: ./scripts/bootstrap.sh [file ...] | doctor | test'; echo 'Set NVIM_WORKSPACE=/absolute/path to edit another directory.'; exit 0 ;;
esac
if [[ ! -t 0 || ! -t 1 ]]; then echo 'Open an interactive terminal, or run ./scripts/bootstrap.sh test.' >&2; exit 1; fi
exec docker compose run --build --rm nvim "$@"
