#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export NVIM_APPNAME=${NVIM_APPNAME:-jose-nvim}

mode=edit
case ${1:-} in
  install|doctor|test) mode=$1; shift ;;
  --help|-h)
    echo 'Usage: ./scripts/bootstrap.sh [file ...] | install | doctor | test'
    echo '  install  Link the configuration and restore locked plugins without opening the editor.'
    echo '  doctor   Check native dependencies without changing your configuration.'
    echo '  test     Install, restore plugins, and run headless smoke checks.'
    echo 'Set NVIM_APPNAME to choose a profile (default: jose-nvim).'
    echo 'Set NVIM_WORKSPACE to open another directory (default: current directory).'
    exit 0 ;;
esac

if [[ ! "$NVIM_APPNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo 'Use an app name containing letters, digits, underscores, or hyphens.' >&2
  exit 1
fi
if [[ "$mode" != edit && $# -gt 0 ]]; then
  echo "The $mode command does not accept file arguments. See --help." >&2
  exit 1
fi

check_dependencies() {
  local missing=0 tool
  for tool in nvim git cc curl rg node tree-sitter unzip; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Missing dependency: $tool" >&2
      missing=1
    fi
  done
  if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
    echo 'Missing dependency: fd (fd-find on Debian/Ubuntu)' >&2
    missing=1
  fi
  if command -v nvim >/dev/null 2>&1 && ! nvim --clean --headless \
    '+lua if vim.fn.has("nvim-0.11.5") == 0 then vim.cmd("cquit 1") end' +qa; then
    echo 'Neovim 0.11.5 or newer is required.' >&2
    missing=1
  fi
  if (( missing )); then
    echo "Install the native dependencies listed in $repo_dir/README.md, then retry." >&2
    return 1
  fi
  echo 'Native dependencies are ready.'
}

check_dependencies
if [[ "$mode" == doctor ]]; then exit 0; fi
if [[ "$mode" == edit ]]; then
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo 'Open an interactive terminal, or use ./scripts/bootstrap.sh install (or test) for headless setup.' >&2
    exit 1
  fi
  cd -- "${NVIM_WORKSPACE:-$PWD}"
fi

"$repo_dir/scripts/install.sh"
echo 'Restoring plugins from lazy-lock.json...'
NVIM_REDUCED_MOTION=1 nvim --headless '+Lazy! restore' \
  '+lua dofile(vim.fn.stdpath("config") .. "/scripts/check.lua")'

case "$mode" in
  install|test) exit 0 ;;
esac
exec nvim "$@"
