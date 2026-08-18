# Dotfiles

Personal development environment for macOS and Linux, managed with [GNU Stow][gnu-stow].

## What's Included

- **Dual shell support** — [Zsh][zsh] and [Fish][fish] with 200+ shared abbreviations from a single YAML source
- **AI-native workflow** — Shell functions (`ai-commit`, `ai-explain`, `ai-fix`) that use the [Claude CLI][claude-code]
- **[Neovim][neovim]** configured with [LazyVim][lazyvim]
- **[Starship][starship]** cross-shell prompt
- **[ghostty][ghostty]** terminal + [tmux][tmux] multiplexer
- **[Atuin][atuin]** shell history with fuzzy search and optional cross-machine sync
- **Abbreviation auditor** — finds unused abbreviations and suggests new ones from your actual shell history
- **One-command setup** — bootstrap a fresh machine in under 10 minutes
- **Cross-platform** — macOS (Apple Silicon + Intel) and Linux (Ubuntu/Debian, CachyOS/Arch)

## Quick Start

### Fresh Machine (recommended)

One command — works on macOS, Ubuntu/Debian, and CachyOS/Arch:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/petrex/dotfiles/master/scripts/bootstrap.sh)
```

`scripts/bootstrap.sh` handles everything: prerequisites (Xcode CLI tools / `base-devel` / build-essential), Homebrew or pacman/apt, repo clone into `~/dotfiles`, stow symlinks, asdf + language runtimes, package install (Brewfile / `pacman.txt` / `apt.txt`), and zsh as the default shell. Safe to re-run (idempotent).

```bash
# Preview without making changes
bash <(curl -fsSL https://raw.githubusercontent.com/petrex/dotfiles/master/scripts/bootstrap.sh) --dry-run

# Skip the lengthy Brewfile install (macOS)
./scripts/bootstrap.sh --skip-brew-bundle

# All flags
./scripts/bootstrap.sh --help
```

### Already have the repo

If you've already cloned the repo and just want to (re)create symlinks:

```bash
git clone https://github.com/petrex/dotfiles.git ~/dotfiles   # if needed
~/dotfiles/setup.sh --dry-run                                  # preview
~/dotfiles/setup.sh                                            # apply
```

`setup.sh` only handles stow symlinks; for full bootstrap (packages, runtimes, shell), use `scripts/bootstrap.sh`.

### Post-Install

- Launch `nvim` and run `:checkhealth`
- Create `~/.gitconfig.local` with your name and email
- Install tmux plugins: `<prefix> + I`
- (Optional) Set up [1Password CLI][1p-cli-start] for secrets management

## Common Operations

```bash
make help        # Show all available targets
make setup       # Run full setup (install deps, create symlinks)
make audit       # Audit abbreviations against shell history (requires atuin)
make lint        # Lint shell scripts with shellcheck + shfmt
make test        # Run the test suite
make sync-abbr   # Regenerate Fish and Zsh abbreviation files from YAML
make validate    # Run configuration validators
```

## AI Shell Functions

Three standalone bash scripts that use the `claude` CLI. They work in any shell and gracefully fall back when Claude isn't installed.

| Command | Usage | What it does |
|---------|-------|-------------|
| `ai-commit` | `ai-commit` | Generates a conventional commit message from staged changes |
| `ai-explain` | `some_command 2>&1 \| ai-explain` | Explains command output in plain English |
| `ai-fix` | `failed_command 2>&1 \| ai-fix` | Suggests a fix for error output |

## Shell Setup

Both Zsh and Fish are supported with functional parity via shared configuration:

- Same prompt ([Starship][starship])
- 200+ identical abbreviations generated from `shared/abbreviations.yaml`
- Shared environment variables (`shared/environment.sh` / `shared/environment.fish`)
- Smart git functions with automatic branch detection (`gpum`, `grbm`, `gcom`, `gbrm`)

### Adding Abbreviations

```bash
# 1. Edit the single source of truth
vim ~/dotfiles/shared/abbreviations.yaml

# 2. Regenerate shell-specific files
make sync-abbr

# 3. Reload your shell
exec fish   # or: src (Zsh)
```

> **Important:** Never edit the generated abbreviation files directly.

### Abbreviation Auditor

Cross-references your actual shell history (via [Atuin][atuin]) against your abbreviations to find what you don't use and what you should add:

```bash
make audit                              # Report only
./scripts/audit-abbreviations.sh --fix  # Remove unused + regenerate
```

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `asdf/` | asdf version manager config |
| `atuin/` | Atuin shell history config |
| `bin/` | Custom scripts (`ai-commit`, `ai-explain`, `ai-fix`, git wrappers, tmux helpers) |
| `brew/` | Homebrew Brewfile |
| `claude/` | Claude Code configuration and custom commands |
| `fish/` | Fish shell config |
| `ghostty/` | Ghostty terminal config |
| `git/` | Git configuration |
| `kitty/` | Kitty terminal config |
| `nvim/` | Neovim (LazyVim) config |
| `scripts/` | Bootstrap, validation, linting, testing, abbreviation auditor |
| `shared/` | Cross-shell abbreviations, environment variables, generators |
| `starship/` | Starship prompt config |
| `tmux/` | Tmux config |
| `zsh/` | Zsh shell config |

## Testing and Validation

```bash
# Run the full test suite (bats-core)
./scripts/run-tests

# Lint shell scripts
./scripts/lint-shell

# Validate configurations (shell syntax, abbreviations, environment, dependencies, markdown)
./scripts/validate-config.sh
./scripts/validate-config.sh --fix    # Auto-fix common issues
```

CI runs automatically on push via GitHub Actions (tests, validation, performance, security).

## Platform Support

- **macOS** — Apple Silicon and Intel, Homebrew for packages
- **Ubuntu/Debian** — apt + PPAs via `packages/apt.txt` and `packages/ubuntu-extra.sh`
- **CachyOS/Arch** — pacman via `packages/pacman.txt` and `packages/cachyos-extra.sh`

Shell configs include cross-platform guards. `bootstrap.sh` detects the OS and package manager automatically.

## Neovim

Uses the [LazyVim][lazyvim] distribution. Custom plugins and overrides live in `nvim/.config/nvim/lua/plugins/`. Plugins install automatically on first launch.

## Fonts

Installed via Homebrew Cask Fonts:

- [Cascadia Code][cascadia-code]
- [Fira Code][fira-code]
- [Hack][hack]
- [JetBrains Mono][jetbrains-mono]
- [Monaspace][monaspace]
- [Symbols Nerd Font Mono][symbols-nerd-font-mono] (icons without patched fonts)

## Customization

Local overrides go in `*.local` files (gitignored):

- `~/.gitconfig.local` — personal git settings
- `~/.zshrc.local` — Zsh-specific overrides
- `~/dotfiles/local/config.fish.local` — Fish-specific overrides

## Credits

Originally forked from [joshukraine/dotfiles](https://github.com/joshukraine/dotfiles). Restructured as an independent project with AI-native tooling, cross-platform support, and an abbreviation auditor.

## License

[MIT License](LICENSE)

[1p-cli-start]: https://developer.1password.com/docs/cli/get-started
[atuin]: https://atuin.sh/
[cascadia-code]: https://github.com/microsoft/cascadia-code
[claude-code]: https://claude.ai/code
[fira-code]: https://github.com/tonsky/FiraCode
[fish]: http://fishshell.com/
[ghostty]: https://ghostty.org/
[gnu-stow]: https://www.gnu.org/software/stow/
[hack]: https://sourcefoundry.org/hack
[jetbrains-mono]: https://www.jetbrains.com/lp/mono/
[lazyvim]: https://www.lazyvim.org/
[monaspace]: https://monaspace.githubnext.com
[neovim]: https://neovim.io/
[starship]: https://starship.rs/
[symbols-nerd-font-mono]: https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
[tmux]: https://github.com/tmux/tmux/wiki
[zsh]: https://zsh.sourceforge.io/
