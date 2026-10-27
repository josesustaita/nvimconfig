<p align="center"><img src="docs/banner.svg" alt="Neovim config — a little flow for your editor" width="100%" /></p>

# Jose's Neovim workbench ✦

A Catppuccin-flavored LazyVim setup with smooth scrolling and resizing, sensible language extras, and tmux navigation. It runs directly on your machine using a separate Neovim profile.

## Temporary SSH sessions

SSH into the server, then bootstrap a temporary work shell:

```bash
exec bash <(curl -fsSL https://raw.githubusercontent.com/josesustaita/nvimconfig/main/scripts/remote.sh) --shell
```

Run `nvim` normally throughout that SSH session. Quit Neovim with `:qa`, work at the shell, then open another file whenever needed. The downloaded editor, configuration, plugins, and caches stay available between editor launches. Plugins download on the first launch and are reused afterward.

```bash
nvim /path/to/file
# After quitting Neovim, open another file from the same prompt:
nvim /path/to/another/file
```

Run `exit` when finished: it cleans up the temporary setup and ends the SSH connection. Disconnecting also triggers cleanup. `exec` replaces your original SSH shell; omit `exec` if you prefer to return to your original SSH prompt after cleanup. A `[jose-nvim]` prompt identifies the work shell. The script reads your `.bashrc`, scopes temporary editor settings to the `nvim` launcher, and keeps shell history inside the temporary session. Other shell commands retain their normal environment.

Use Bash with an interactive terminal. The server needs **Git, curl, and tar**, internet access to GitHub, and permission to write the files you want to edit. No sudo or system-package installation is used. A compatible installed Neovim is reused; otherwise the script downloads Neovim **v0.11.5** into the temporary session. Automatic downloads support compatible glibc-based Linux and macOS on x86_64/arm64, using the [official Neovim archives](https://neovim.io/doc/install/).

The editor keeps your theme, navigation, and motion settings. This server profile skips Copilot, language servers, parser compilation, and native completion, so Node.js, language toolchains, and a C compiler are unnecessary. Existing `rg` and `fd` improve searching, but are optional for this workflow.

Saved changes to the files you edited stay in place after cleanup. The script copies the config into a private temporary directory and leaves your installed editor, shell configuration, and normal Neovim profile alone. A forced kill (`kill -9`) of the wrapper or power loss cannot run cleanup; the session directory printed at startup identifies any leftover files. If `/tmp` is mounted with `noexec`, set `TMPDIR` to a writable directory that permits executables before bootstrapping, for example `export TMPDIR="$HOME"`.

From an existing checkout:

```bash
./scripts/bootstrap.sh remote --shell
```

No arguments also selects shell mode. Passing file arguments instead starts a single editor session and cleans up when that editor exits:

```bash
./scripts/bootstrap.sh remote /path/to/file
```

To test a branch before it is merged, set `NVIM_CONFIG_REF` to that branch and fetch `scripts/remote.sh` from the matching branch URL.

## Persistent local setup

Install the [native dependencies](#native-dependencies) below, then run:

```bash
git clone --depth 1 https://github.com/josesustaita/nvimconfig.git
cd nvimconfig
./scripts/bootstrap.sh
```

The bootstrap checks your tools, links this checkout at `${XDG_CONFIG_HOME:-~/.config}/jose-nvim`, restores plugins from `lazy-lock.json`, runs smoke checks, and opens Neovim. Internet access is needed to download plugins and language tools on first setup. Later runs reuse the same local data. Keep this checkout in place while the symlink is in use.

Your normal `nvim` configuration stays untouched. The installer refuses to replace an existing destination and is safe to rerun. To use this as your default configuration instead, run `NVIM_APPNAME=nvim ./scripts/bootstrap.sh`; an existing `nvim` configuration must be moved aside first. Use the same `NVIM_APPNAME` when installing, checking, and launching a custom profile.

```bash
./scripts/bootstrap.sh init.lua
NVIM_WORKSPACE=/absolute/path/to/project ./scripts/bootstrap.sh
NVIM_REDUCED_MOTION=1 ./scripts/bootstrap.sh
./scripts/bootstrap.sh doctor    # dependency checks only; no install
./scripts/bootstrap.sh install   # setup without opening the editor
./scripts/bootstrap.sh test      # setup and headless smoke checks
```

File paths are relative to your current directory, or to `NVIM_WORKSPACE` when set. After setup, launch directly from any project directory without restoring plugins again:

```bash
NVIM_APPNAME=jose-nvim nvim
```

To create only the configuration link, use `./scripts/install.sh`. Neovim then downloads plugins when first launched. To leave Neovim, use `:qa` (`:qa!` discards unsaved edits).

## Native dependencies

Use Bash on Linux, macOS, or WSL. Install **Neovim 0.11.5+**, Git, a C compiler (`cc`), curl, ripgrep, fd (`fdfind` also works), Node.js, Tree-sitter CLI, and unzip. Python 3 with venv support is useful for Python-based Mason tools. A Nerd Font is optional for richer icons. See the upstream [Neovim installation guide](https://neovim.io/doc/install/) and [LazyVim requirements](https://www.lazyvim.org/#%EF%B8%8F-requirements).

On macOS with Homebrew:

```bash
xcode-select --install  # if Command Line Tools are not already installed
brew install neovim git curl ripgrep fd node tree-sitter unzip python
```

On Debian/Ubuntu or Ubuntu in WSL:

```bash
sudo apt-get update
sudo apt-get install -y neovim git build-essential curl ca-certificates ripgrep fd-find nodejs npm unzip python3 python3-venv
npm install --global --prefix "$HOME/.local" tree-sitter-cli
export PATH="$HOME/.local/bin:$PATH"
```

Add the PATH line to your shell startup file to keep the Tree-sitter CLI available in future terminals. Some distro releases ship an older Neovim: check `nvim --version`. If it is below 0.11.5, install the **v0.11.5** archive for your OS/architecture from [Neovim releases](https://github.com/neovim/neovim/releases/tag/v0.11.5) and put its `bin` directory first on PATH. Use a current Node.js LTS release if your distro's version is too old for language tools.

The scripts check dependencies and configure Neovim; system packages remain managed by your package manager. Go and Rust extras need their project toolchains for language servers and builds. Language tools are managed through `:Mason` and can finish installing on first interactive launch; the bootstrap smoke check does not wait for every language server to install.

## A few keys to know

`<leader>` is Space; use `:Lazy` to inspect plugins and `:checkhealth` for environment diagnostics.

| Key                     | Action                                               |
| ----------------------- | ---------------------------------------------------- |
| `<leader>ua`            | Toggle scrolling/resizing animations                 |
| `<leader><space>`       | Find files (LazyVim default)                         |
| `<leader>sg`            | Search project text (LazyVim default)                |
| `Ctrl+h/j/k/l`          | Navigate windows/tmux panes in normal mode           |
| `Ctrl+\`                | Return to the previous tmux pane                     |
| `Ctrl+j` in insert mode | Accept a visible Copilot suggestion, when configured |

Copilot is optional and requires your own account authorization (`:Copilot auth`). There is no API key bundled with this repo and no ChatGPT plugin configured. Regular editing works without AI access.

## Motion with an off switch

`mini.animate` adds short scrolling and resize transitions. Cursor trails and animated window opening/closing are disabled. Set `NVIM_REDUCED_MOTION=1` before launch for a still editor, or toggle with `<leader>ua`. The animated README banner respects your browser's reduced-motion setting.

## Configuration map

- `init.lua` / `lua/config/lazy.lua` — plugin bootstrap and pinned LazyVim release.
- `lazy-lock.json` — exact plugin revisions; commit intentional updates.
- `lazyvim.json` — Go, Rust, TypeScript, Python, SQL, CMake, Docker, JSON, YAML, TOML, Tailwind, Markdown, Prettier, yank history, dial, color highlights, and Copilot extras.
- `lua/config/options.lua` / `keymaps.lua` — motion settings and custom keys.
- `lua/plugins/` — Catppuccin, animations, pairing, autotags, and tmux navigation.
- `scripts/check.lua` — headless plugin and reduced-motion smoke checks.
- `scripts/remote.sh` / `lua/plugins/server.lua` — disposable SSH sessions and the lighter server profile.

The full profile includes the extras from my local Neovim setup. Bootstrapping downloads their plugins automatically, including CMake tools, Python environment selection, Dadbod's database UI/completion, Markdown preview/rendering, yank history, dial, and color highlights. Their revisions are pinned in `lazy-lock.json`; language servers and formatters are managed separately through Mason.

The bootstrap uses [`:Lazy restore`](https://lazy.folke.io/usage) to align plugins with the committed lockfile. To update deliberately, run `:Lazy sync`, inspect the changed `lazy-lock.json`, and commit intentional updates. After pulling changes, rerun `./scripts/bootstrap.sh install` to restore the new locked versions.

## Troubleshooting

- **No icons:** use a Nerd Font, or keep editing with the textual controls.
- **Plugin download failed:** check network access, rerun `./scripts/bootstrap.sh install`, and inspect `:Lazy`.
- **Language server missing:** inspect `:Mason` and `:checkhealth`; some languages require additional project toolchains or provider access.
- **Configuration already exists:** choose a different `NVIM_APPNAME` or move the existing configuration aside yourself; the installer never overwrites it.
- **Missing or old tools:** run `./scripts/bootstrap.sh doctor` and check the dependency instructions above.
- **Terminal required:** use the interactive bootstrap for editing and `./scripts/bootstrap.sh test` in CI.

## Development checks

Run `python3 -m unittest discover -s tests -v` to check installer safety, dependency failures, profile selection, remote downloads, isolated state, and cleanup on exit or signals with temporary directories and stub tools. Run `bash -n scripts/*.sh` and `shellcheck scripts/*.sh` for shell checks. With native dependencies installed, `./scripts/bootstrap.sh test` restores real plugins and checks startup, plugin installation, and reduced motion for the selected profile.

Licensed under [Apache 2.0](LICENSE).
