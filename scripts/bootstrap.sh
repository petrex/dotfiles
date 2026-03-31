#!/usr/bin/env bash

set -e

################################################################################
# bootstrap.sh
#
# Single bootstrap script to set up a fresh macOS, Ubuntu, or CachyOS/Arch
# machine from zero. Installs prerequisites, clones the dotfiles repo, runs
# setup.sh, installs language runtimes, and configures the default shell.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/pyeh/dotfiles/master/scripts/bootstrap.sh)
#
# Or after cloning:
#   ./scripts/bootstrap.sh [OPTIONS]
#
# Options:
#   --dry-run            Show what would be done without making changes
#   --skip-brew-bundle   Skip the full Brewfile install (macOS Phase 8)
#   --help               Show this help message
#
# Supported platforms:
#   macOS (Apple Silicon + Intel)
#   Ubuntu / Debian (apt)
#   CachyOS / Arch Linux (pacman)
################################################################################

# ---------------------------------------------------------------------------
# Phase 0: Preflight
# ---------------------------------------------------------------------------

DOTFILES_REPO="https://github.com/pyeh/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"
DOTFILES_BRANCH="master"

DRY_RUN=false
SKIP_BREW_BUNDLE=false

# Platform globals — set in preflight()
OS=""           # "macos" | "linux"
DISTRO=""       # "macos" | "ubuntu" | "cachyos" | "arch"
PKG_MGR=""      # "brew" | "apt" | "pacman"
HOMEBREW_PREFIX=""

# Logging helpers (mirrors setup.sh patterns)
bootstrap_echo() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "\\n[BOOTSTRAP] ${fmt}\\n" "$@"
}

bootstrap_info() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "[INFO] ${fmt}\\n" "$@"
}

bootstrap_warn() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "[WARN] ${fmt}\\n" "$@" >&2
}

bootstrap_error() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "[ERROR] ${fmt}\\n" "$@" >&2
}

run_cmd() {
  local cmd="$1"
  local description="${2:-}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would run: %s" "${cmd}"
    if [[ -n "${description}" ]]; then
      bootstrap_info "  Purpose: %s" "${description}"
    fi
  else
    bootstrap_info "Running: %s" "${cmd}"
    eval "${cmd}"
  fi
}

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Bootstrap a fresh macOS, Ubuntu, or CachyOS/Arch machine from zero.
Installs prerequisites, clones dotfiles, runs setup.sh, installs language
runtimes, and configures the default shell.

Supported platforms:
  macOS (Apple Silicon + Intel) — uses Homebrew
  Ubuntu / Debian              — uses apt
  CachyOS / Arch Linux         — uses pacman

Options:
  --dry-run            Show what would be done without making changes
  --skip-brew-bundle   Skip the full Brewfile install (macOS only)
  --help               Show this help message

Examples:
  bash <(curl -fsSL https://raw.githubusercontent.com/pyeh/dotfiles/master/scripts/bootstrap.sh)
  $0                      # Full bootstrap
  $0 --dry-run            # Preview all phases
  $0 --skip-brew-bundle   # Skip lengthy Brewfile install (macOS)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --skip-brew-bundle)
        SKIP_BREW_BUNDLE=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        bootstrap_error "Unknown option: %s" "$1"
        show_help
        exit 1
        ;;
    esac
  done
}

preflight() {
  bootstrap_echo "Phase 0: Preflight checks"

  local osname
  osname="$(uname)"

  case "${osname}" in
    Darwin)
      OS="macos"
      DISTRO="macos"
      PKG_MGR="brew"
      bootstrap_info "macOS detected"

      local arch
      arch="$(uname -m)"
      if [[ "${arch}" == "arm64" ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
        bootstrap_info "Apple Silicon detected — HOMEBREW_PREFIX=%s" "${HOMEBREW_PREFIX}"
      else
        HOMEBREW_PREFIX="/usr/local"
        bootstrap_info "Intel Mac detected — HOMEBREW_PREFIX=%s" "${HOMEBREW_PREFIX}"
      fi
      ;;
    Linux)
      OS="linux"
      if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "${ID}" in
          ubuntu|debian)
            DISTRO="ubuntu"
            PKG_MGR="apt"
            bootstrap_info "Ubuntu/Debian detected — using apt"
            ;;
          cachyos)
            DISTRO="cachyos"
            PKG_MGR="pacman"
            bootstrap_info "CachyOS detected — using pacman"
            ;;
          arch)
            # shellcheck disable=SC2034
            DISTRO="arch"
            PKG_MGR="pacman"
            bootstrap_info "Arch Linux detected — using pacman"
            ;;
          *)
            bootstrap_error "Unsupported Linux distribution: %s" "${ID}"
            exit 1
            ;;
        esac
      else
        bootstrap_error "/etc/os-release not found — cannot detect distribution"
        exit 1
      fi
      ;;
    *)
      bootstrap_error "Unsupported operating system: %s" "${osname}"
      exit 1
      ;;
  esac

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_echo "DRY RUN MODE — no changes will be made"
  fi
}

# ---------------------------------------------------------------------------
# Phase 1: Build Tools
# ---------------------------------------------------------------------------

install_build_tools() {
  bootstrap_echo "Phase 1: Build tools"

  case "${OS}" in
    macos)
      # Xcode Command Line Tools
      if xcode-select -p &>/dev/null; then
        bootstrap_info "Xcode CLI tools already installed"
        return
      fi

      if [[ "${DRY_RUN}" == "true" ]]; then
        bootstrap_info "[DRY RUN] Would install Xcode CLI tools"
        return
      fi

      bootstrap_info "Installing Xcode Command Line Tools..."
      xcode-select --install

      bootstrap_info "Waiting for Xcode CLI tools installation to complete..."
      until xcode-select -p &>/dev/null; do
        sleep 5
      done
      bootstrap_info "Xcode CLI tools installed"
      ;;
    linux)
      case "${PKG_MGR}" in
        apt)
          run_cmd "sudo apt update && sudo apt install -y build-essential curl git" \
            "Install build essentials for Ubuntu"
          ;;
        pacman)
          run_cmd "sudo pacman -Syu --noconfirm && sudo pacman -S --needed --noconfirm base-devel curl git" \
            "Install build essentials for Arch/CachyOS"
          ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Phase 2: Rosetta 2 (macOS Apple Silicon only)
# ---------------------------------------------------------------------------

install_rosetta() {
  bootstrap_echo "Phase 2: Rosetta 2"

  if [[ "${OS}" != "macos" ]]; then
    bootstrap_info "Not macOS — skipping Rosetta"
    return
  fi

  if [[ "$(uname -m)" != "arm64" ]]; then
    bootstrap_info "Not Apple Silicon — skipping Rosetta"
    return
  fi

  if pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto &>/dev/null; then
    bootstrap_info "Rosetta 2 already installed"
    return
  fi

  run_cmd "softwareupdate --install-rosetta --agree-to-license" "Install Rosetta 2"
}

# ---------------------------------------------------------------------------
# Phase 3: Package Manager + Minimal Packages
# ---------------------------------------------------------------------------

install_packages_minimal() {
  bootstrap_echo "Phase 3: Package manager + minimal packages"

  case "${PKG_MGR}" in
    brew)
      if command -v "${HOMEBREW_PREFIX}/bin/brew" &>/dev/null; then
        bootstrap_info "Homebrew already installed"
      else
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would install Homebrew"
        else
          bootstrap_info "Installing Homebrew..."
          NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
      fi

      # Ensure brew is on PATH for this session
      if [[ "${DRY_RUN}" == "false" ]]; then
        eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"
      fi

      # Minimal formulae needed for subsequent phases
      local minimal_formulae=(git stow coreutils openssl@3 libyaml readline zsh)

      bootstrap_info "Installing minimal formulae: %s" "${minimal_formulae[*]}"
      for formula in "${minimal_formulae[@]}"; do
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would install: %s" "${formula}"
        else
          brew install "${formula}" 2>/dev/null || true
        fi
      done
      ;;
    apt)
      local minimal_apt=(git stow zsh curl build-essential)
      bootstrap_info "Installing minimal apt packages: %s" "${minimal_apt[*]}"
      if [[ "${DRY_RUN}" == "true" ]]; then
        bootstrap_info "[DRY RUN] Would install: %s" "${minimal_apt[*]}"
      else
        sudo apt install -y "${minimal_apt[@]}"
      fi
      ;;
    pacman)
      local minimal_pacman=(git stow zsh curl base-devel)
      bootstrap_info "Installing minimal pacman packages: %s" "${minimal_pacman[*]}"
      if [[ "${DRY_RUN}" == "true" ]]; then
        bootstrap_info "[DRY RUN] Would install: %s" "${minimal_pacman[*]}"
      else
        sudo pacman -S --needed --noconfirm "${minimal_pacman[@]}"
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Phase 4: Clone Dotfiles
# ---------------------------------------------------------------------------

clone_dotfiles() {
  bootstrap_echo "Phase 4: Clone dotfiles"

  if [[ -d "${DOTFILES_DIR}" ]]; then
    bootstrap_info "Dotfiles directory already exists at %s" "${DOTFILES_DIR}"
    if [[ "${DRY_RUN}" == "true" ]]; then
      bootstrap_info "[DRY RUN] Would pull latest changes"
    else
      bootstrap_info "Pulling latest changes..."
      git -C "${DOTFILES_DIR}" pull --ff-only || bootstrap_warn "Could not fast-forward; continuing with existing checkout"
    fi
  else
    run_cmd "git clone -b '${DOTFILES_BRANCH}' '${DOTFILES_REPO}' '${DOTFILES_DIR}'" \
      "Clone dotfiles repo"
  fi
}

# ---------------------------------------------------------------------------
# Phase 5: Run setup.sh
# ---------------------------------------------------------------------------

run_setup_sh() {
  bootstrap_echo "Phase 5: Run setup.sh"

  local setup_cmd="bash '${DOTFILES_DIR}/setup.sh'"
  if [[ "${DRY_RUN}" == "true" ]]; then
    setup_cmd="${setup_cmd} --dry-run"
  fi

  run_cmd "${setup_cmd}" "Run dotfiles setup (stow symlinks, hostname, directories, tmux)"
}

# ---------------------------------------------------------------------------
# Phase 6: asdf + Language Runtimes
# ---------------------------------------------------------------------------

add_or_update_asdf_plugin() {
  local name="$1"
  local url="$2"

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would add/update asdf plugin: %s" "${name}"
    return
  fi

  if ! asdf plugin list 2>/dev/null | grep -Fq "${name}"; then
    asdf plugin add "${name}" "${url}"
  else
    asdf plugin update "${name}"
  fi
}

install_asdf_language() {
  local language="$1"

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would install asdf language: %s" "${language}"
    return
  fi

  local versions
  # Read versions for this language from .tool-versions
  versions="$(grep "^${language} " "${HOME}/.tool-versions" | sed "s/^${language} //")"

  if [[ -z "${versions}" ]]; then
    bootstrap_warn "No version found for %s in .tool-versions" "${language}"
    return
  fi

  for version in ${versions}; do
    if asdf list "${language}" 2>/dev/null | grep -Fq "${version}"; then
      bootstrap_info "%s %s already installed" "${language}" "${version}"
    else
      bootstrap_info "Installing %s %s ..." "${language}" "${version}"
      asdf install "${language}" "${version}"
    fi
  done
}

install_asdf_languages() {
  bootstrap_echo "Phase 6: asdf + language runtimes"

  if [[ "${DRY_RUN}" == "false" ]]; then
    case "${OS}" in
      macos)
        brew install asdf 2>/dev/null || true
        # shellcheck source=/dev/null
        source "$(brew --prefix asdf)/libexec/asdf.sh" 2>/dev/null || true
        ;;
      linux)
        if [[ ! -d "${HOME}/.asdf" ]]; then
          bootstrap_info "Installing asdf via git clone..."
          git clone https://github.com/asdf-vm/asdf.git "${HOME}/.asdf" --branch v0.15.0
        else
          bootstrap_info "asdf already installed at ~/.asdf"
        fi
        # shellcheck source=/dev/null
        source "${HOME}/.asdf/asdf.sh"

        # Install asdf build dependencies on Ubuntu
        if [[ "${PKG_MGR}" == "apt" ]]; then
          bootstrap_info "Installing asdf build dependencies for Ubuntu..."
          sudo apt install -y autoconf bison libssl-dev libreadline-dev \
            zlib1g-dev libncurses-dev libffi-dev libgdbm-dev libyaml-dev
        fi
        ;;
    esac
  else
    case "${OS}" in
      macos)
        bootstrap_info "[DRY RUN] Would install asdf via Homebrew"
        ;;
      linux)
        bootstrap_info "[DRY RUN] Would install asdf via git clone"
        ;;
    esac
  fi

  add_or_update_asdf_plugin "ruby" "https://github.com/asdf-vm/asdf-ruby.git"
  add_or_update_asdf_plugin "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"
  add_or_update_asdf_plugin "python" "https://github.com/asdf-community/asdf-python.git"
  add_or_update_asdf_plugin "lua" "https://github.com/Stratus3D/asdf-lua.git"

  install_asdf_language "ruby"
  install_asdf_language "nodejs"
  install_asdf_language "python"

  # luarocks 3.13+ has rockspec syntax incompatible with Lua 5.1's parser
  ASDF_LUA_LUAROCKS_VERSION="3.11.1" install_asdf_language "lua"

  # Configure bundler parallelism
  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would configure bundler jobs"
  else
    local num_cpus
    if [[ "${OS}" == "macos" ]]; then
      num_cpus="$(sysctl -n hw.ncpu)"
    else
      num_cpus="$(nproc)"
    fi
    bundle config --global jobs "$((num_cpus - 1))" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Phase 7: Gems + npm Packages
# ---------------------------------------------------------------------------

gem_install_or_update() {
  local gem_name="$1"

  if gem list "${gem_name}" --installed >/dev/null 2>&1; then
    bootstrap_info "Updating gem: %s" "${gem_name}"
    gem update "${gem_name}" --no-document || true
  else
    bootstrap_info "Installing gem: %s" "${gem_name}"
    gem install "${gem_name}" --no-document || true
  fi
}

install_gems_and_npm() {
  bootstrap_echo "Phase 7: Gems + npm packages"

  # Install gems from ~/.default-gems
  if [[ -f "${HOME}/.default-gems" ]]; then
    bootstrap_info "Installing gems from ~/.default-gems ..."
    if [[ "${DRY_RUN}" == "true" ]]; then
      bootstrap_info "[DRY RUN] Would install gems: %s" "$(tr '\n' ' ' <"${HOME}/.default-gems")"
    else
      while IFS= read -r gem_name; do
        [[ -z "${gem_name}" ]] && continue
        gem_install_or_update "${gem_name}"
      done <"${HOME}/.default-gems"
    fi
  else
    bootstrap_warn "%s/.default-gems not found — skipping gem installation" "${HOME}"
  fi

  # Install npm packages from ~/.default-npm-packages
  if [[ -f "${HOME}/.default-npm-packages" ]]; then
    bootstrap_info "Installing npm packages from ~/.default-npm-packages ..."
    if [[ "${DRY_RUN}" == "true" ]]; then
      bootstrap_info "[DRY RUN] Would install npm packages: %s" "$(tr '\n' ' ' <"${HOME}/.default-npm-packages")"
    else
      while IFS= read -r pkg_name; do
        [[ -z "${pkg_name}" ]] && continue
        bootstrap_info "Installing npm package: %s" "${pkg_name}"
        npm install -g "${pkg_name}" || bootstrap_warn "Failed to install npm package: %s" "${pkg_name}"
      done <"${HOME}/.default-npm-packages"
    fi
  else
    bootstrap_warn "%s/.default-npm-packages not found — skipping npm installation" "${HOME}"
  fi
}

# ---------------------------------------------------------------------------
# Phase 8: Full Package Install
# ---------------------------------------------------------------------------

install_packages_full() {
  bootstrap_echo "Phase 8: Full package install"

  case "${PKG_MGR}" in
    brew)
      if [[ "${SKIP_BREW_BUNDLE}" == "true" ]]; then
        bootstrap_info "Skipping brew bundle install (--skip-brew-bundle)"
        return
      fi

      if [[ ! -f "${HOME}/Brewfile" ]]; then
        bootstrap_warn "%s/Brewfile not found — skipping brew bundle" "${HOME}"
        return
      fi

      run_cmd "brew bundle install --file='${HOME}/Brewfile'" \
        "Install packages from Brewfile (this may take a while)"
      ;;
    apt)
      local pkg_file="${DOTFILES_DIR}/packages/apt.txt"
      if [[ ! -f "${pkg_file}" ]]; then
        bootstrap_warn "packages/apt.txt not found — skipping"
        return
      fi

      bootstrap_info "Installing apt packages from packages/apt.txt..."
      if [[ "${DRY_RUN}" == "true" ]]; then
        bootstrap_info "[DRY RUN] Would install packages from %s" "${pkg_file}"
      else
        # shellcheck disable=SC2046
        sudo apt install -y $(cat "${pkg_file}")
      fi

      # Install extra tools (PPAs, binaries, etc.)
      local extra_script="${DOTFILES_DIR}/packages/ubuntu-extra.sh"
      if [[ -f "${extra_script}" ]]; then
        bootstrap_info "Running ubuntu-extra.sh for additional tools..."
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would source %s" "${extra_script}"
        else
          # shellcheck source=../packages/ubuntu-extra.sh
          source "${extra_script}"
        fi
      fi
      ;;
    pacman)
      local pkg_file="${DOTFILES_DIR}/packages/pacman.txt"
      if [[ ! -f "${pkg_file}" ]]; then
        bootstrap_warn "packages/pacman.txt not found — skipping"
        return
      fi

      bootstrap_info "Installing pacman packages from packages/pacman.txt..."
      if [[ "${DRY_RUN}" == "true" ]]; then
        bootstrap_info "[DRY RUN] Would install packages from %s" "${pkg_file}"
      else
        # shellcheck disable=SC2046
        sudo pacman -S --needed --noconfirm $(cat "${pkg_file}")
      fi

      # Install extra tools (AUR, etc.)
      local extra_script="${DOTFILES_DIR}/packages/cachyos-extra.sh"
      if [[ -f "${extra_script}" ]]; then
        bootstrap_info "Running cachyos-extra.sh for additional tools..."
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would source %s" "${extra_script}"
        else
          # shellcheck source=../packages/cachyos-extra.sh
          source "${extra_script}"
        fi
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Phase 9: Zsh + Zap
# ---------------------------------------------------------------------------

setup_zsh() {
  bootstrap_echo "Phase 9: Zsh + Zap"

  local zsh_path
  if [[ "${OS}" == "macos" ]]; then
    zsh_path="${HOMEBREW_PREFIX}/bin/zsh"
  else
    zsh_path="$(command -v zsh)"
  fi

  # Add zsh to /etc/shells if missing
  if ! grep -Fq "${zsh_path}" /etc/shells 2>/dev/null; then
    run_cmd "echo '${zsh_path}' | sudo tee -a /etc/shells" \
      "Add Zsh to /etc/shells"
  else
    bootstrap_info "Zsh already in /etc/shells"
  fi

  # Set as default shell
  if [[ "${SHELL}" != "${zsh_path}" ]]; then
    run_cmd "chsh -s '${zsh_path}'" "Set Zsh as default shell"
  else
    bootstrap_info "Zsh already the default shell"
  fi

  # Install Zap plugin manager
  if [[ -d "${HOME}/.local/share/zap" ]]; then
    bootstrap_info "Zap already installed"
  else
    if [[ "${DRY_RUN}" == "true" ]]; then
      bootstrap_info "[DRY RUN] Would install Zap (Zsh plugin manager) with --keep flag"
    else
      bootstrap_info "Installing Zap (Zsh plugin manager)..."
      zsh <(curl -fsSL https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1 --keep
    fi
  fi
}

# ---------------------------------------------------------------------------
# Phase 10: Summary
# ---------------------------------------------------------------------------

show_summary() {
  bootstrap_echo "Phase 10: Bootstrap complete!"

  cat <<'EOF'

Remaining manual steps:
  -> Launch nvim and run :checkhealth
  -> Create ~/.gitconfig.local with your name and email
  -> Install Tmux plugins: start tmux, then press <prefix> + I
  -> Restart your terminal to pick up all changes

EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  preflight

  install_build_tools
  install_rosetta
  install_packages_minimal
  clone_dotfiles
  run_setup_sh
  install_asdf_languages
  install_gems_and_npm
  install_packages_full
  setup_zsh
  show_summary
}

trap 'bootstrap_error "Script failed at line %s" "$LINENO"' ERR

main "$@"
