#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_name=${NVIM_APPNAME:-jose-nvim}
if [[ ! "$app_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then echo "Use an app name containing letters, digits, underscores, or hyphens." >&2; exit 1; fi
config_root=${XDG_CONFIG_HOME:-$HOME/.config}
destination="$config_root/$app_name"
if [[ -e "$destination" || -L "$destination" ]]; then
  if [[ -L "$destination" && $(readlink "$destination") == "$repo_dir" ]]; then echo "Already linked: $destination"; else echo "Already exists: $destination. Choose a different NVIM_APPNAME; no files were changed." >&2; exit 1; fi
else
  mkdir -p -- "$config_root"
  ln -s -- "$repo_dir" "$destination"
fi
printf 'Launch with: NVIM_APPNAME=%s nvim\n' "$app_name"
