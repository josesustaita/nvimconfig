#!/usr/bin/env bash
# Standalone entry point: also works with bash <(curl -fsSL .../scripts/remote.sh).
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: remote.sh [--shell | Neovim arguments ...]'
  echo 'With no arguments (or --shell), keep Neovim available in a session shell.'
  echo 'Exit the shell or disconnect to clean up. File arguments open a single editor session.'
  echo 'Requires Bash, Git, curl, tar, and an interactive terminal. No sudo needed.'
  exit 0
fi
mode=editor
if [[ $# -eq 0 || ${1:-} == --shell ]]; then
  mode=shell
  if [[ $# -gt 0 ]]; then shift; fi
  if [[ $# -gt 0 ]]; then
    echo 'The --shell option does not accept file arguments; run nvim inside the session shell.' >&2
    exit 1
  fi
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  echo 'Run in an interactive terminal: bash <(curl -fsSL URL) [file ...]' >&2
  exit 1
fi
for tool in git curl tar; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing dependency: $tool" >&2
    exit 1
  fi
done

# Save the caller's environment so other commands in the session shell keep
# their usual configuration. Only the nvim launcher receives isolated paths.
shell_environment=(env)
shell_variables=(XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR TMPDIR NVIM_APPNAME NVIM_SERVER_MODE PATH)
for variable in "${shell_variables[@]}"; do
  if [[ ! ${!variable+x} ]]; then shell_environment+=(-u "$variable"); fi
done
for variable in "${shell_variables[@]}"; do
  if [[ ${!variable+x} ]]; then shell_environment+=("$variable=${!variable}"); fi
done
original_umask=$(umask)
umask 077
temp_root=$(cd -- "${TMPDIR:-/tmp}" && pwd -P)
session_dir=$(mktemp -d "$temp_root/jose-nvim.XXXXXXXX")
shell_pid=
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$shell_pid" ]]; then
    kill -HUP "$shell_pid" 2>/dev/null || true
    wait "$shell_pid" 2>/dev/null || true
  fi
  rm -rf -- "$session_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'Temporary Neovim session: %s\n' "$session_dir"

export XDG_CONFIG_HOME="$session_dir/config"
export XDG_DATA_HOME="$session_dir/data"
export XDG_STATE_HOME="$session_dir/state"
export XDG_CACHE_HOME="$session_dir/cache"
export XDG_RUNTIME_DIR="$session_dir/run"
export TMPDIR="$session_dir/tmp"
export NVIM_APPNAME=jose-nvim
export NVIM_SERVER_MODE=1
mkdir -p -- "$XDG_CONFIG_HOME/$NVIM_APPNAME" "$XDG_RUNTIME_DIR" "$TMPDIR"
config_dir="$XDG_CONFIG_HOME/$NVIM_APPNAME"

# Copy only editor files so a local checkout and its Git history stay untouched.
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ ! -f "$source_dir/init.lua" ]]; then
  source_dir="$session_dir/source"
  mkdir -p -- "$source_dir"
  curl -fsSL --retry 3 \
    "https://github.com/josesustaita/nvimconfig/archive/${NVIM_CONFIG_REF:-main}.tar.gz" \
    -o "$session_dir/config.tar.gz"
  tar -xzf "$session_dir/config.tar.gz" --strip-components=1 -C "$source_dir"
fi
cp -- "$source_dir/init.lua" "$source_dir/lazy-lock.json" "$config_dir/"
cp -R -- "$source_dir/lua" "$config_dir/"
# The temporary profile needs no language extras or account authorization.
cat > "$config_dir/lazyvim.json" <<'JSON'
{"extras": [], "news": {"NEWS.md": "2123"}, "version": 8}
JSON

if ! command -v nvim >/dev/null 2>&1 || ! nvim --clean --headless \
  '+lua if vim.fn.has("nvim-0.11.5") == 0 then vim.cmd("cquit 1") end' +qa; then
  case $(uname -s) in
    Linux) platform=linux ;;
    Darwin) platform=macos ;;
    *) echo 'Automatic Neovim download supports Linux and macOS. Install Neovim 0.11.5+ first.' >&2; exit 1 ;;
  esac
  case $(uname -m) in
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo 'Automatic Neovim download supports x86_64 and arm64. Install Neovim 0.11.5+ first.' >&2; exit 1 ;;
  esac
  archive="nvim-$platform-$arch"
  echo 'Downloading Neovim v0.11.5 for this session...'
  curl -fsSL --retry 3 \
    "https://github.com/neovim/neovim/releases/download/v0.11.5/$archive.tar.gz" \
    -o "$session_dir/nvim.tar.gz"
  tar -xzf "$session_dir/nvim.tar.gz" -C "$session_dir"
  export PATH="$session_dir/$archive/bin:$PATH"
fi

# Keep swap/backup files with the disposable state, never beside edited files.
nvim_command='lua vim.opt.directory = vim.fn.stdpath("state") .. "/swap//"; vim.opt.backupdir = vim.fn.stdpath("state") .. "/backup//"'
if [[ "$mode" == shell ]]; then
  session_bin="$session_dir/bin"
  mkdir -p -- "$session_bin"
  {
    printf '#!/usr/bin/env bash\nexec env '
    for variable in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR TMPDIR NVIM_APPNAME NVIM_SERVER_MODE; do
      printf '%q ' "$variable=${!variable}"
    done
    printf '%q ' "$(command -v nvim)" --cmd "$nvim_command"
    printf '"$@"\n'
  } > "$session_bin/nvim"
  chmod +x -- "$session_bin/nvim"
  # Variables in the generated rc file expand in the interactive child shell.
  # shellcheck disable=SC2016
  {
    printf 'if [[ -f "$HOME/.bashrc" ]]; then source "$HOME/.bashrc"; fi\n'
    printf 'unalias nvim 2>/dev/null || true\nunset -f nvim\n'
    printf 'export PATH=%q:"$PATH"\nhash -r\n' "$session_bin"
    printf 'HISTFILE=%q\n' "$session_dir/bash_history"
    printf 'PS1="[jose-nvim] ${PS1:-\\$ }"\n'
    printf 'echo "Neovim is ready: use nvim as often as needed. Exit this shell to clean up."\n'
  } > "$session_dir/bashrc"
  umask "$original_umask"
  # wait lets this parent handle disconnects promptly and forward them to Bash.
  # Explicit stdin preserves the terminal for the interactive child.
  "${shell_environment[@]}" bash --noprofile --rcfile "$session_dir/bashrc" -i <&0 &
  shell_pid=$!
  shell_status=0
  wait "$shell_pid" || shell_status=$?
  shell_pid=
  exit "$shell_status"
else
  umask "$original_umask"
  nvim --cmd "$nvim_command" "$@"
fi
