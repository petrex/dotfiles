#!/usr/bin/env bash

# -E propagates the ERR trap into functions. Without it, a failure inside any
# phase function exits the script silently, with no indication of where it died.
set -Ee

################################################################################
# bootstrap.sh
#
# Single bootstrap script to set up a fresh macOS, Ubuntu, or CachyOS/Arch
# machine from zero. Installs prerequisites, clones the dotfiles repo, runs
# setup.sh, installs language runtimes, and configures the default shell.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/petrex/dotfiles/master/scripts/bootstrap.sh)
#
# Or after cloning:
#   ./scripts/bootstrap.sh [OPTIONS]
#
# Options:
#   --dry-run            Show what would be done without making changes
#   --skip-packages      Skip the full Phase 8 package install (all platforms)
#   --skip-brew-bundle   Alias of --skip-packages, kept for compatibility
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

DOTFILES_REPO="https://github.com/petrex/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"
DOTFILES_BRANCH="master"

DRY_RUN=false
SKIP_BREW_BUNDLE=false
SKIP_PACKAGES=false

# Platform globals — set in preflight()
OS=""      # "macos" | "linux"
DISTRO=""  # "macos" | "ubuntu" | "cachyos" | "arch"
PKG_MGR="" # "brew" | "apt" | "pacman"
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

# Ask for the admin password up front, then keep the sudo timestamp warm.
#
# Every Linux phase shells out to sudo, but none of them ever prompted: when a
# non-interactive apt/pacman call hits a password requirement it simply fails,
# and `set -e` killed the bootstrap with no explanation. This mirrors what
# Phase 3 already does before running the Homebrew installer on macOS.
SUDO_KEEPALIVE_PID=""

prime_sudo() {
  local purpose="${1:-installing packages}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would request administrator access for %s" "${purpose}"
    return 0
  fi

  # Already root, or a passwordless sudo timestamp is live — nothing to ask for.
  if [[ "${EUID}" -eq 0 ]] || sudo -n true 2>/dev/null; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    bootstrap_warn "No terminal available — cannot prompt for the sudo password."
    bootstrap_warn "This needs passwordless sudo and will fail otherwise."
    return 0
  fi

  bootstrap_info "Administrator access is required for %s." "${purpose}"
  if ! sudo -v; then
    bootstrap_error "Could not obtain administrator access."
    bootstrap_error "This script needs an account with sudo rights. Re-run from one."
    exit 1
  fi

  # Package installs routinely outlast sudo's 5-minute timeout, which would
  # strand a later phase back in the no-password state mid-run.
  [[ -n "${SUDO_KEEPALIVE_PID}" ]] && return 0
  while true; do
    sleep 60
    kill -0 "$$" 2>/dev/null || exit 0
    sudo -n true 2>/dev/null || exit 0
  done &
  SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID}" ]]; then
    kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
    SUDO_KEEPALIVE_PID=""
  fi
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
  --skip-packages      Skip the full package install in Phase 8 (all platforms)
  --skip-brew-bundle   Alias of --skip-packages, kept for compatibility
  --help               Show this help message

Examples:
  bash <(curl -fsSL https://raw.githubusercontent.com/petrex/dotfiles/master/scripts/bootstrap.sh)
  $0                      # Full bootstrap
  $0 --dry-run            # Preview all phases
  $0 --skip-packages      # Skip the lengthy Phase 8 package install
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --skip-packages)
        # Cross-platform: skips Phase 8 on every platform.
        SKIP_PACKAGES=true
        SKIP_BREW_BUNDLE=true
        shift
        ;;
      --skip-brew-bundle)
        # Retained for compatibility; --skip-packages is the portable spelling.
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
          ubuntu | debian)
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
            # Derivatives (Pop!_OS, Mint, EndeavourOS, Manjaro...) carry their
            # own ID but declare their base in ID_LIKE. Fall back to that
            # rather than refusing to run on a machine we can handle.
            case " ${ID_LIKE:-} " in
              *" ubuntu "* | *" debian "*)
                DISTRO="ubuntu"
                PKG_MGR="apt"
                bootstrap_info "%s detected (Debian-family via ID_LIKE) — using apt" "${ID}"
                ;;
              *" arch "*)
                # shellcheck disable=SC2034
                DISTRO="arch"
                PKG_MGR="pacman"
                bootstrap_info "%s detected (Arch-family via ID_LIKE) — using pacman" "${ID}"
                ;;
              *)
                bootstrap_error "Unsupported Linux distribution: %s" "${ID}"
                bootstrap_error "Supported: Ubuntu/Debian (apt), CachyOS/Arch (pacman)"
                exit 1
                ;;
            esac
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

  # apt will happily block forever on a debconf prompt or, on Ubuntu 22.04+, on
  # needrestart's "which services should be restarted?" dialog. An unattended
  # bootstrap has nobody to answer either, so answer them here.
  if [[ "${PKG_MGR}" == "apt" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export NEEDRESTART_SUSPEND=1
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_echo "DRY RUN MODE — no changes will be made"
  fi
}

# Read a newline-delimited package list, dropping blank lines and comments.
#
# The Brewfile is Ruby and has always tolerated comments; apt.txt and
# pacman.txt were fed straight into `$(cat ...)`, so a single `#` note would
# have been passed to the package manager as a package name. Now they support
# the same annotation style the Brewfile uses.
read_package_list() {
  local list_file="$1"
  sed -E 's/#.*$//; s/[[:space:]]+$//' "${list_file}" | grep -v '^[[:space:]]*$' || true
}

# Install packages without letting one bad name cost the entire list.
#
# `apt install a b typo` and `pacman -S a b typo` both abort outright and
# install *nothing*, so one stale entry took down the whole phase — and with it
# the rest of the bootstrap. `brew bundle` on macOS has always continued past a
# failure and reported at the end; this gives Linux the same behaviour by
# retrying package-by-package and reporting what could not be installed.
install_package_list() {
  local -a packages=("$@")
  local -a failed=()
  local pkg

  [[ ${#packages[@]} -eq 0 ]] && return 0

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would install %d package(s): %s" "${#packages[@]}" "${packages[*]}"
    return 0
  fi

  bootstrap_info "Installing %d package(s) via %s" "${#packages[@]}" "${PKG_MGR}"
  if linux_install_packages "${packages[@]}"; then
    return 0
  fi

  bootstrap_warn "Bulk install failed — retrying package-by-package to isolate the bad entries"
  for pkg in "${packages[@]}"; do
    linux_install_packages "${pkg}" || failed+=("${pkg}")
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    bootstrap_warn "Could not install %d package(s): %s" "${#failed[@]}" "${failed[*]}"
    bootstrap_warn "Continuing — check the names against your distro's repositories."
  fi
  return 0
}

linux_install_packages() {
  case "${PKG_MGR}" in
    apt) sudo -E apt-get install -y "$@" ;;
    pacman) sudo pacman -S --needed --noconfirm "$@" ;;
    *)
      bootstrap_warn "No Linux package manager set — cannot install: %s" "$*"
      return 1
      ;;
  esac
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
      # First sudo of the run — ask for the password now rather than letting a
      # non-interactive package manager fail against an empty timestamp.
      prime_sudo "installing build tools"

      case "${PKG_MGR}" in
        apt)
          run_cmd "sudo -E apt-get update" "Refresh apt package index" \
            || bootstrap_warn "apt-get update failed — continuing with the existing index"
          install_package_list build-essential curl git ca-certificates
          ;;
        pacman)
          run_cmd "sudo pacman -Syu --noconfirm" "Refresh and upgrade pacman packages" \
            || bootstrap_warn "pacman -Syu failed — continuing with the existing database"
          install_package_list base-devel curl git ca-certificates
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
      local brew_bin="${HOMEBREW_PREFIX}/bin/brew"

      if [[ -x "${brew_bin}" ]]; then
        bootstrap_info "Homebrew already installed at %s" "${brew_bin}"
      elif [[ "${DRY_RUN}" == "true" ]]; then
        bootstrap_info "[DRY RUN] Would install Homebrew"
      else
        bootstrap_info "Installing Homebrew..."

        # Download and run as separate steps. With `bash -c "$(curl ...)"` a
        # failed download collapses to `bash -c ""`, which exits 0 — so the
        # bootstrap would march on as if Homebrew had been installed and then
        # fail confusingly several phases later.
        local installer
        installer="$(mktemp)"
        if ! curl -fsSL \
          https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
          -o "${installer}"; then
          rm -f "${installer}"
          bootstrap_error "Could not download the Homebrew installer — check network access"
          exit 1
        fi

        # NONINTERACTIVE=1 makes Homebrew's installer pass -n to sudo, so it can
        # never prompt for a password and simply aborts when one is required —
        # the reason this phase exited without ever asking for admin access.
        # Ask for the password up front instead, then let the install run
        # unattended on the resulting sudo timestamp.
        if [[ -t 0 ]]; then
          bootstrap_info "Homebrew needs administrator access to install."
          if ! sudo -v; then
            rm -f "${installer}"
            bootstrap_error "Could not obtain administrator access."
            bootstrap_error "Homebrew requires an account with sudo rights. Re-run from one."
            exit 1
          fi

          # The install can outlast sudo's timeout (5 minutes by default), which
          # would strand it back in the no-password state mid-run.
          sudo -n true 2>/dev/null
          while true; do
            sleep 60
            kill -0 "$$" 2>/dev/null || exit 0
            sudo -n true 2>/dev/null || exit 0
          done &
          local sudo_keepalive_pid=$!
        else
          bootstrap_warn "No terminal available — running the installer non-interactively."
          bootstrap_warn "This needs passwordless sudo and will fail otherwise."
        fi

        # Let the check below report the failure with something actionable,
        # rather than `set -e` killing the script with no explanation.
        NONINTERACTIVE=1 /bin/bash "${installer}" || true

        if [[ -n "${sudo_keepalive_pid:-}" ]]; then
          kill "${sudo_keepalive_pid}" 2>/dev/null || true
        fi
        rm -f "${installer}"
      fi

      # The installer needs sudo and can fail or land outside HOMEBREW_PREFIX,
      # so confirm brew really is usable before anything depends on it.
      if [[ ! -x "${brew_bin}" ]]; then
        brew_bin="$(command -v brew || true)"
      fi

      if [[ "${DRY_RUN}" == "false" && ! -x "${brew_bin}" ]]; then
        bootstrap_error "Homebrew is still not available after Phase 3."
        bootstrap_error "It needs sudo access from an admin account. Install it manually:"
        # shellcheck disable=SC2016  # literal command for the user to copy, not for expansion
        bootstrap_error '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        bootstrap_error "then re-run this script."
        exit 1
      fi

      # Ensure brew is on PATH for this session
      if [[ "${DRY_RUN}" == "false" ]]; then
        eval "$("${brew_bin}" shellenv)"
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
      # unzip is not a nicety: bun's installer (Phase 10) extracts a zip and
      # fails on a minimal image without it.
      local minimal_apt=(git stow zsh curl unzip build-essential)
      bootstrap_info "Installing minimal apt packages: %s" "${minimal_apt[*]}"
      prime_sudo "installing base packages"
      install_package_list "${minimal_apt[@]}"
      verify_minimal_linux_packages
      ;;
    pacman)
      local minimal_pacman=(git stow zsh curl unzip base-devel)
      bootstrap_info "Installing minimal pacman packages: %s" "${minimal_pacman[*]}"
      prime_sudo "installing base packages"
      install_package_list "${minimal_pacman[@]}"
      verify_minimal_linux_packages
      ;;
  esac
}

# Confirm the tools the *later* phases hard-depend on actually landed.
#
# macOS verifies brew is executable before continuing and exits with something
# actionable if not. Linux had no equivalent: a failed install left the run to
# collapse several phases later, far from the cause.
verify_minimal_linux_packages() {
  [[ "${DRY_RUN}" == "true" ]] && return 0

  local -a required=(git stow curl)
  local -a missing=()
  local tool

  for tool in "${required[@]}"; do
    command -v "${tool}" >/dev/null 2>&1 || missing+=("${tool}")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    bootstrap_error "Required tool(s) still missing after Phase 3: %s" "${missing[*]}"
    bootstrap_error "Install them manually, then re-run this script:"
    case "${PKG_MGR}" in
      apt) bootstrap_error "  sudo apt-get install -y %s" "${missing[*]}" ;;
      pacman) bootstrap_error "  sudo pacman -S --needed %s" "${missing[*]}" ;;
    esac
    exit 1
  fi

  bootstrap_info "Verified: git, stow and curl are available"
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

  # A failing plugin should not abort the remaining phases of the bootstrap.
  if ! asdf plugin list 2>/dev/null | grep -Fqx "${name}"; then
    asdf plugin add "${name}" "${url}" \
      || bootstrap_warn "Failed to add asdf plugin: %s" "${name}"
  else
    asdf plugin update "${name}" \
      || bootstrap_warn "Failed to update asdf plugin: %s" "${name}"
  fi
}

install_asdf_language() {
  local language="$1"

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would install asdf language: %s" "${language}"
    return
  fi

  if [[ ! -f "${HOME}/.tool-versions" ]]; then
    bootstrap_warn "%s/.tool-versions not found — skipping %s" "${HOME}" "${language}"
    return
  fi

  local versions
  # Read versions for this language from .tool-versions. `|| true` keeps a
  # no-match grep (exit 1) from tripping `set -e` and killing the bootstrap
  # before the empty-check below can report it.
  versions="$(grep "^${language} " "${HOME}/.tool-versions" | sed "s/^${language} //")" || true

  if [[ -z "${versions}" ]]; then
    bootstrap_warn "No version found for %s in .tool-versions" "${language}"
    return
  fi

  for version in ${versions}; do
    if asdf list "${language}" 2>/dev/null | grep -Fq "${version}"; then
      bootstrap_info "%s %s already installed" "${language}" "${version}"
    else
      bootstrap_info "Installing %s %s ..." "${language}" "${version}"
      # One runtime failing to build should not abort phases 7-12.
      asdf install "${language}" "${version}" \
        || bootstrap_warn "Failed to install %s %s — continuing" "${language}" "${version}"
    fi
  done
}

# Install asdf on Linux, preferring the same generation macOS gets.
#
# Homebrew hands macOS asdf 0.16+ (a single Go binary), but Linux was pinned to
# a v0.15.0 git clone — a different, end-of-life implementation. Install the
# release binary so both platforms run the same asdf, falling back to the old
# clone if the download is unavailable for this architecture.
install_asdf_linux() {
  if command -v asdf >/dev/null 2>&1 || [[ -x "${HOME}/.asdf/bin/asdf" ]]; then
    bootstrap_info "asdf already installed"
    return 0
  fi

  local arch asdf_arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64) asdf_arch="amd64" ;;
    aarch64 | arm64) asdf_arch="arm64" ;;
    i386 | i686) asdf_arch="386" ;;
    *)
      bootstrap_warn "Unrecognised architecture %s — falling back to the asdf git clone" "${arch}"
      install_asdf_linux_git
      return $?
      ;;
  esac

  local tag
  tag="$(curl -fsSL https://api.github.com/repos/asdf-vm/asdf/releases/latest 2>/dev/null \
    | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)" || true

  if [[ -z "${tag}" ]]; then
    bootstrap_warn "Could not determine the latest asdf release — falling back to the git clone"
    install_asdf_linux_git
    return $?
  fi

  local url="https://github.com/asdf-vm/asdf/releases/download/${tag}/asdf-${tag}-linux-${asdf_arch}.tar.gz"
  local tarball
  tarball="$(mktemp)"

  bootstrap_info "Installing asdf %s (linux-%s)..." "${tag}" "${asdf_arch}"
  if ! curl -fsSL "${url}" -o "${tarball}"; then
    rm -f "${tarball}"
    bootstrap_warn "Could not download %s — falling back to the git clone" "${url}"
    install_asdf_linux_git
    return $?
  fi

  mkdir -p "${HOME}/.local/bin"
  if ! tar -xzf "${tarball}" -C "${HOME}/.local/bin" asdf; then
    rm -f "${tarball}"
    bootstrap_warn "Could not extract the asdf archive — falling back to the git clone"
    install_asdf_linux_git
    return $?
  fi

  rm -f "${tarball}"
  chmod +x "${HOME}/.local/bin/asdf"
  export PATH="${HOME}/.local/bin:${PATH}"
  bootstrap_info "asdf installed to %s/.local/bin/asdf" "${HOME}"
}

install_asdf_linux_git() {
  if [[ -d "${HOME}/.asdf" ]]; then
    bootstrap_info "asdf already present at ~/.asdf"
    return 0
  fi
  bootstrap_info "Installing asdf via git clone (v0.15.0)..."
  git clone https://github.com/asdf-vm/asdf.git "${HOME}/.asdf" --branch v0.15.0 \
    || bootstrap_warn "Could not clone asdf — language runtimes will be skipped"
}

# Put asdf on PATH for the rest of this script.
#
# asdf >= 0.16 is a single Go binary and no longer ships libexec/asdf.sh, so the
# old `source .../asdf.sh` is a no-op there and shims never reach PATH — which
# left every later phase resolving `gem`/`npm` against the system runtimes.
# Source the shell hook only when it actually exists (asdf <= 0.15), and always
# export the shims directory, matching the pattern in zsh/.zshrc.
setup_asdf_shell() {
  local candidate
  for candidate in \
    "$(brew --prefix asdf 2>/dev/null || true)/libexec/asdf.sh" \
    "${HOME}/.asdf/asdf.sh"; do
    if [[ -f "${candidate}" ]]; then
      bootstrap_info "Sourcing legacy asdf shell hook: %s" "${candidate}"
      # shellcheck source=/dev/null
      source "${candidate}"
      break
    fi
  done

  export ASDF_DATA_DIR="${ASDF_DATA_DIR:-${HOME}/.asdf}"

  # Cover every place asdf can land: the shims, the Linux release binary in
  # ~/.local/bin, and the bin/ of a v0.15 git clone.
  local dir
  for dir in "${ASDF_DATA_DIR}/shims" "${HOME}/.local/bin" "${HOME}/.asdf/bin"; do
    [[ -d "${dir}" ]] || continue
    case ":${PATH}:" in
      *":${dir}:"*) ;;
      *) export PATH="${dir}:${PATH}" ;;
    esac
  done

  if ! command -v asdf >/dev/null 2>&1; then
    bootstrap_warn "asdf not found on PATH — skipping language runtime setup"
    return 1
  fi

  bootstrap_info "Using %s" "$(asdf --version 2>&1)"
}

install_asdf_languages() {
  bootstrap_echo "Phase 6: asdf + language runtimes"

  if [[ "${DRY_RUN}" == "false" ]]; then
    case "${OS}" in
      macos)
        brew install asdf 2>/dev/null || true
        ;;
      linux)
        install_asdf_linux

        # Build dependencies for the Ruby/Node compiles that follow. Arch was
        # previously skipped entirely, so `asdf install ruby` failed there for
        # want of openssl/readline/libyaml headers.
        prime_sudo "installing language build dependencies"
        case "${PKG_MGR}" in
          apt)
            bootstrap_info "Installing asdf build dependencies for Ubuntu/Debian..."
            install_package_list autoconf bison libssl-dev libreadline-dev \
              zlib1g-dev libncurses-dev libffi-dev libgdbm-dev libyaml-dev
            ;;
          pacman)
            bootstrap_info "Installing asdf build dependencies for Arch/CachyOS..."
            install_package_list autoconf bison openssl readline zlib \
              ncurses libffi gdbm libyaml
            ;;
        esac
        ;;
    esac

    setup_asdf_shell || return 0
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
  add_or_update_asdf_plugin "lua" "https://github.com/Stratus3D/asdf-lua.git"

  install_asdf_language "ruby"
  install_asdf_language "nodejs"

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

# Homebrew 6+ refuses to load formulae from non-official taps until they are
# explicitly trusted, which aborts `brew bundle install` with:
#   Refusing to load formula olets/tap/zsh-abbr from untrusted tap olets/tap.
#
# Trust exactly the taps this Brewfile already declares. This is deliberately
# not a blanket bypass of the check — taps added later still require a decision.
trust_brewfile_taps() {
  local brewfile="$1"

  # `brew trust` only exists on Homebrew 6+; older versions need no trusting.
  if ! brew commands 2>/dev/null | grep -qx trust; then
    bootstrap_info "This Homebrew has no 'brew trust' — skipping tap trust step"
    return
  fi

  # brew stores trust in ${XDG_CONFIG_HOME}/homebrew/trust.json, falling back to
  # ~/.homebrew/trust.json when XDG_CONFIG_HOME is unset. Bootstrap runs before
  # any shell config is loaded, so without this the trust would be written to the
  # fallback path while the configured shell later reads the XDG one — and the
  # untrusted-tap error would come back. Pin it to the value the rest of the
  # dotfiles use (shared/environment.sh, setup.sh).
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

  local tap
  while IFS= read -r tap; do
    [[ -z "${tap}" ]] && continue
    if [[ "${DRY_RUN}" == "true" ]]; then
      bootstrap_info "[DRY RUN] Would trust tap: %s" "${tap}"
    else
      bootstrap_info "Trusting tap: %s" "${tap}"
      brew trust --tap "${tap}" || bootstrap_warn "Could not trust tap: %s" "${tap}"
    fi
  done < <(sed -nE 's/^[[:space:]]*tap[[:space:]]+"([^"]+)".*/\1/p' "${brewfile}")
}

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

      trust_brewfile_taps "${HOME}/Brewfile"

      run_cmd "brew bundle install --file='${HOME}/Brewfile'" \
        "Install packages from Brewfile (this may take a while)"
      ;;
    apt | pacman)
      if [[ "${SKIP_PACKAGES}" == "true" ]]; then
        bootstrap_info "Skipping full package install (--skip-packages)"
        return
      fi

      local pkg_file extra_script
      if [[ "${PKG_MGR}" == "apt" ]]; then
        pkg_file="${DOTFILES_DIR}/packages/apt.txt"
        extra_script="${DOTFILES_DIR}/packages/ubuntu-extra.sh"
      else
        pkg_file="${DOTFILES_DIR}/packages/pacman.txt"
        extra_script="${DOTFILES_DIR}/packages/cachyos-extra.sh"
      fi

      if [[ ! -f "${pkg_file}" ]]; then
        bootstrap_warn "%s not found — skipping" "${pkg_file}"
        return
      fi

      prime_sudo "installing packages"

      # Refresh the index first. Phase 1 did this, but several phases and a
      # long compile have happened since, and apt fails outright on a stale
      # index once a mirror rotates.
      if [[ "${PKG_MGR}" == "apt" ]]; then
        run_cmd "sudo -E apt-get update" "Refresh apt package index" \
          || bootstrap_warn "apt-get update failed — continuing with the existing index"
      fi

      bootstrap_info "Installing packages from %s..." "${pkg_file}"
      local -a pkgs=()
      while IFS= read -r pkg; do
        pkgs+=("${pkg}")
      done < <(read_package_list "${pkg_file}")
      install_package_list "${pkgs[@]}"

      # Extra tools: PPAs and binary installs on Ubuntu, AUR on Arch.
      if [[ -f "${extra_script}" ]]; then
        bootstrap_info "Running %s for additional tools..." "$(basename "${extra_script}")"
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would run %s" "${extra_script}"
        else
          # Run in a subshell, not sourced: these scripts set their own `set -e`
          # and define helpers like command_exists(). Sourcing let a single
          # failed extra abort the whole bootstrap and leaked its functions
          # into every later phase.
          # shellcheck disable=SC1090
          (source "${extra_script}") \
            || bootstrap_warn "%s reported errors — continuing" "$(basename "${extra_script}")"
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
    # `command -v` exits non-zero when zsh is absent, which under `set -e` took
    # the whole script down at this assignment — no message, no phases 10-12.
    zsh_path="$(command -v zsh || true)"
    if [[ -z "${zsh_path}" ]]; then
      bootstrap_warn "zsh not found on PATH — skipping shell setup"
      case "${PKG_MGR}" in
        apt) bootstrap_warn "Install it with: sudo apt-get install -y zsh" ;;
        pacman) bootstrap_warn "Install it with: sudo pacman -S --needed zsh" ;;
      esac
      return 0
    fi
  fi

  prime_sudo "registering zsh as a login shell"

  # Add zsh to /etc/shells if missing
  if ! grep -Fq "${zsh_path}" /etc/shells 2>/dev/null; then
    run_cmd "echo '${zsh_path}' | sudo tee -a /etc/shells" \
      "Add Zsh to /etc/shells" \
      || bootstrap_warn "Could not add %s to /etc/shells" "${zsh_path}"
  else
    bootstrap_info "Zsh already in /etc/shells"
  fi

  # Set as default shell. chsh fails for accounts managed outside /etc/passwd
  # (LDAP, SSSD, some cloud images) — a warning there, not a dead bootstrap.
  if [[ "${SHELL}" != "${zsh_path}" ]]; then
    run_cmd "chsh -s '${zsh_path}'" "Set Zsh as default shell" || {
      bootstrap_warn "Could not change the default shell automatically."
      bootstrap_warn "Set it manually with: chsh -s %s" "${zsh_path}"
    }
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
# Phase 10: gstack (Garry Tan's Claude Code skill suite)
# ---------------------------------------------------------------------------

install_gstack() {
  bootstrap_echo "Phase 10: gstack"

  local gstack_repo="https://github.com/garrytan/gstack.git"
  local gstack_dir="${HOME}/.claude/skills/gstack"

  # gstack requires bun v1.0+ — install if missing
  if command -v bun &>/dev/null || [[ -x "${HOME}/.bun/bin/bun" ]]; then
    bootstrap_info "bun already installed"
  else
    case "${OS}" in
      macos)
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would install bun via Homebrew"
        else
          bootstrap_info "Installing bun (gstack runtime)..."
          brew install bun || bootstrap_warn "brew install bun failed"
        fi
        ;;
      linux)
        if [[ "${DRY_RUN}" == "true" ]]; then
          bootstrap_info "[DRY RUN] Would install bun via https://bun.sh/install"
        else
          # bun's installer unpacks a zip; without unzip it fails with a bare
          # "unzip is required to install bun".
          if ! command -v unzip >/dev/null 2>&1; then
            bootstrap_info "Installing unzip (required by the bun installer)..."
            prime_sudo "installing unzip"
            install_package_list unzip
          fi
          bootstrap_info "Installing bun (gstack runtime)..."
          curl -fsSL https://bun.sh/install | bash || bootstrap_warn "bun install script failed"
        fi
        ;;
    esac
  fi

  # Make ~/.bun/bin available for gstack ./setup if bun was just installed there
  if [[ -d "${HOME}/.bun/bin" ]]; then
    export PATH="${HOME}/.bun/bin:${PATH}"
  fi

  # Ensure parent directory exists
  if [[ "${DRY_RUN}" == "false" ]]; then
    mkdir -p "${HOME}/.claude/skills"
  fi

  # Clone or update gstack repo
  if [[ -d "${gstack_dir}/.git" ]]; then
    bootstrap_info "gstack already cloned at %s" "${gstack_dir}"
    if [[ "${DRY_RUN}" == "true" ]]; then
      bootstrap_info "[DRY RUN] Would update gstack via git pull"
    else
      git -C "${gstack_dir}" pull --ff-only || bootstrap_warn "Could not update gstack; continuing"
    fi
  else
    run_cmd "git clone --single-branch --depth 1 '${gstack_repo}' '${gstack_dir}'" \
      "Clone gstack repo"
  fi

  # Run gstack's installer
  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would run gstack ./setup"
  elif [[ -x "${gstack_dir}/setup" ]]; then
    bootstrap_info "Running gstack setup..."
    (cd "${gstack_dir}" && ./setup) || bootstrap_warn "gstack setup encountered errors"
  else
    bootstrap_warn "gstack setup script not found at %s/setup" "${gstack_dir}"
  fi
}

# ---------------------------------------------------------------------------
# Phase 11: Claude Code plugins (marketplaces + skill bundles)
# ---------------------------------------------------------------------------
#
# Each entry is "marketplace-name:github-owner/repo:plugin@marketplace".
# Mirrors the user-scope plugins recorded in
# ~/.claude/plugins/installed_plugins.json and known_marketplaces.json.

# A marketplace and its plugins are named by the repo's own
# .claude-plugin/marketplace.json, which need not match the repo name --
# affaan-m/everything-claude-code declares both as "ecc". Verify against that
# manifest when adding an entry rather than assuming the repo name.
CLAUDE_PLUGIN_ENTRIES=(
  "ecc:affaan-m/everything-claude-code:ecc@ecc"
  "karpathy-skills:forrestchang/andrej-karpathy-skills:andrej-karpathy-skills@karpathy-skills"
  "last30days-skill:mvanhorn/last30days-skill:last30days@last30days-skill"
)

# macOS gets the claude CLI from the Brewfile (cask "claude-code@latest").
# Linux had no install path at all — neither apt.txt, pacman.txt, nor the
# extra scripts provide it — so Phase 11 could only ever warn and skip.
install_claude_cli() {
  command -v claude >/dev/null 2>&1 && return 0
  [[ -x "${HOME}/.local/bin/claude" ]] && {
    export PATH="${HOME}/.local/bin:${PATH}"
    return 0
  }

  if [[ "${DRY_RUN}" == "true" ]]; then
    bootstrap_info "[DRY RUN] Would install the claude CLI"
    return 1
  fi

  bootstrap_info "Installing the Claude Code CLI..."
  if curl -fsSL https://claude.ai/install.sh | bash; then
    # The native installer drops the binary in ~/.local/bin, which is not yet
    # on PATH in a non-login bootstrap shell.
    case ":${PATH}:" in
      *":${HOME}/.local/bin:"*) ;;
      *) export PATH="${HOME}/.local/bin:${PATH}" ;;
    esac
  elif command -v npm >/dev/null 2>&1; then
    bootstrap_warn "Native installer failed — falling back to npm"
    npm install -g @anthropic-ai/claude-code \
      || bootstrap_warn "npm install of @anthropic-ai/claude-code failed"
  else
    bootstrap_warn "Could not install the claude CLI (no npm available as a fallback)"
  fi

  command -v claude >/dev/null 2>&1
}

install_claude_plugins() {
  bootstrap_echo "Phase 11: Claude Code plugins"

  if ! command -v claude &>/dev/null; then
    if [[ "${OS}" == "linux" ]]; then
      install_claude_cli || true
    fi
  fi

  if ! command -v claude &>/dev/null; then
    bootstrap_warn "claude CLI not found on PATH — skipping plugin installation"
    bootstrap_warn "Install Claude Code first: https://docs.anthropic.com/en/docs/claude-code"
    return
  fi

  local existing_markets=""
  local existing_plugins=""
  if [[ "${DRY_RUN}" == "false" ]]; then
    existing_markets="$(claude plugin marketplace list 2>/dev/null || true)"
    existing_plugins="$(claude plugin list 2>/dev/null || true)"
  fi

  for entry in "${CLAUDE_PLUGIN_ENTRIES[@]}"; do
    local market_name="${entry%%:*}"
    local rest="${entry#*:}"
    local repo="${rest%%:*}"
    local plugin_spec="${rest#*:}"

    # Match the marketplace name as a whole list entry. A bare substring test
    # can match a fragment of another marketplace's name or its source repo.
    if grep -qE "^[^[:alnum:]]*${market_name}[[:space:]]*$" <<<"${existing_markets}"; then
      bootstrap_info "Marketplace already registered: %s" "${market_name}"
    else
      # A single bad plugin should not abort the phase, or Phase 12 never runs.
      run_cmd "claude plugin marketplace add '${repo}'" \
        "Register Claude Code marketplace ${market_name}" \
        || bootstrap_warn "Could not add marketplace %s from %s" "${market_name}" "${repo}"
    fi

    if grep -Fq "${plugin_spec}" <<<"${existing_plugins}"; then
      bootstrap_info "Plugin already installed: %s" "${plugin_spec}"
    else
      run_cmd "claude plugin install '${plugin_spec}' --scope user" \
        "Install Claude Code plugin ${plugin_spec}" \
        || bootstrap_warn "Could not install plugin %s — check that it exists in marketplace %s" \
          "${plugin_spec}" "${market_name}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Phase 12: Summary
# ---------------------------------------------------------------------------

show_summary() {
  bootstrap_echo "Phase 12: Bootstrap complete!"

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
  install_gstack
  install_claude_plugins
  show_summary

  stop_sudo_keepalive
}

trap 'bootstrap_error "Script failed at line %s: %s" "$LINENO" "$BASH_COMMAND"' ERR
# Never leave the background sudo refresher running after the script ends.
trap 'stop_sudo_keepalive' EXIT

main "$@"
