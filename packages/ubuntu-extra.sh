#!/usr/bin/env bash
#
# ubuntu-extra.sh — Install tools not available in default Ubuntu repos
#
# This script is sourced by bootstrap.sh to install PPAs, binary downloads,
# and git-cloned tools on Ubuntu/Debian systems.
#
# Usage: source packages/ubuntu-extra.sh

set -e

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ubuntu_extra_info() {
  printf "[INFO] %s\n" "$1"
}

ubuntu_extra_warn() {
  printf "[WARN] %s\n" "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Download a single static binary from a GitHub release and put it on PATH.
#
# Several tools in the Brewfile have no apt package at all, but do publish
# Linux binaries. This keeps the Ubuntu package set matching macOS instead of
# silently doing without them.
#
# Usage: install_release_binary <command> <owner/repo> <asset-x86_64> <asset-arm64>
install_release_binary() {
  local cmd="$1" repo="$2" asset_x86="$3" asset_arm="$4"
  local asset arch tag url

  if command_exists "${cmd}"; then
    ubuntu_extra_info "${cmd} already installed"
    return 0
  fi

  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64) asset="${asset_x86}" ;;
    aarch64 | arm64) asset="${asset_arm}" ;;
    *)
      ubuntu_extra_warn "No ${cmd} release binary for ${arch} — skipping"
      return 0
      ;;
  esac

  tag="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
    | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)" || true
  if [[ -z "${tag}" ]]; then
    ubuntu_extra_warn "Could not resolve the latest ${cmd} release — skipping"
    return 0
  fi

  url="https://github.com/${repo}/releases/download/${tag}/${asset}"
  ubuntu_extra_info "Installing ${cmd} ${tag} (${arch})..."
  if ! curl -fsSL -o "/tmp/${cmd}.bin" "${url}"; then
    ubuntu_extra_warn "Could not download ${url} — skipping ${cmd}"
    rm -f "/tmp/${cmd}.bin"
    return 0
  fi

  sudo install -m 755 "/tmp/${cmd}.bin" "/usr/local/bin/${cmd}" \
    || ubuntu_extra_warn "Could not install ${cmd} to /usr/local/bin"
  rm -f "/tmp/${cmd}.bin"
}

# ---------------------------------------------------------------------------
# PPAs
# ---------------------------------------------------------------------------

install_eza() {
  if command_exists eza; then
    ubuntu_extra_info "eza already installed"
    return
  fi

  ubuntu_extra_info "Installing eza via apt repository..."
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt update
  sudo apt install -y eza
}

install_gh() {
  if command_exists gh; then
    ubuntu_extra_info "GitHub CLI already installed"
    return
  fi

  ubuntu_extra_info "Installing GitHub CLI via apt repository..."
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt update
  sudo apt install -y gh
}

install_fish() {
  if command_exists fish; then
    ubuntu_extra_info "Fish shell already installed"
    return
  fi

  ubuntu_extra_info "Installing Fish shell via PPA..."
  sudo apt-add-repository -y ppa:fish-shell/release-3
  sudo apt update
  sudo apt install -y fish
}

# ---------------------------------------------------------------------------
# Curl / binary installs
# ---------------------------------------------------------------------------

install_starship() {
  if command_exists starship; then
    ubuntu_extra_info "Starship already installed"
    return
  fi

  # Starship never actually installed here. Its installer escalates whenever
  # BIN_DIR (default /usr/local/bin) is not writable, and it escalates with
  # `sudo -v` -- which validates against *every* sudoers rule. Stock Ubuntu
  # gives every admin `%sudo ALL=(ALL:ALL) ALL`, so `sudo -v` demands a
  # password even where `sudo -n true` already succeeds. A bootstrap has no
  # TTY to type it into, so the installer aborted.
  #
  # The failure was invisible: bootstrap.sh runs this script as
  # `(source ...) || warn`, and being on the left of `||` disables `set -e`
  # for the whole subshell, so the run carried on and reported success.
  #
  # Run the installer as root instead, so BIN_DIR is writable and it never
  # has to escalate at all.
  local installer bin_dir status=0
  installer="$(mktemp)"

  # Downloaded, not piped into sh: a piped installer that fails to download
  # collapses into a no-op that still exits 0.
  if ! curl -fsSL https://starship.rs/install.sh -o "${installer}"; then
    ubuntu_extra_warn "Could not download the Starship installer -- skipping"
    rm -f "${installer}"
    return
  fi

  if sudo -n true 2>/dev/null; then
    bin_dir="/usr/local/bin"
    ubuntu_extra_info "Installing Starship prompt to ${bin_dir}..."
    sudo -E sh "${installer}" --yes --bin-dir "${bin_dir}" || status=$?
  else
    # No non-interactive sudo. A per-user prefix needs none, and bootstrap.sh
    # already puts ~/.local/bin on PATH.
    bin_dir="${HOME}/.local/bin"
    ubuntu_extra_info "No passwordless sudo -- installing Starship to ${bin_dir}..."
    mkdir -p "${bin_dir}"
    sh "${installer}" --yes --bin-dir "${bin_dir}" || status=$?
    case ":${PATH}:" in
      *":${bin_dir}:"*) ;;
      *) export PATH="${bin_dir}:${PATH}" ;;
    esac
  fi
  rm -f "${installer}"

  # Decide by what is on disk, not by the installer's exit status.
  if command_exists starship; then
    ubuntu_extra_info "Starship installed at $(command -v starship)"
  else
    ubuntu_extra_warn "Starship did not install (installer exited ${status})"
    ubuntu_extra_warn "  Install it manually: https://starship.rs/guide/"
  fi
}

install_lazygit() {
  if command_exists lazygit; then
    ubuntu_extra_info "lazygit already installed"
    return
  fi

  ubuntu_extra_info "Installing lazygit..."
  local version
  version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_x86_64.tar.gz"
  tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
  sudo install /tmp/lazygit /usr/local/bin/lazygit
  rm -f /tmp/lazygit /tmp/lazygit.tar.gz
}

install_lazydocker() {
  if command_exists lazydocker; then
    ubuntu_extra_info "lazydocker already installed"
    return
  fi

  ubuntu_extra_info "Installing lazydocker..."
  curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
}

install_uv() {
  if command_exists uv; then
    ubuntu_extra_info "uv already installed"
    return
  fi

  ubuntu_extra_info "Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

# ---------------------------------------------------------------------------
# Binary downloads
# ---------------------------------------------------------------------------

install_shfmt() {
  if command_exists shfmt; then
    ubuntu_extra_info "shfmt already installed"
    return
  fi

  ubuntu_extra_info "Installing shfmt..."
  local arch
  arch=$(dpkg --print-architecture)
  curl -Lo /tmp/shfmt "https://github.com/mvdan/sh/releases/latest/download/shfmt_v3.10.0_linux_${arch}"
  sudo install /tmp/shfmt /usr/local/bin/shfmt
  rm -f /tmp/shfmt
}

install_yq() {
  if command_exists yq; then
    ubuntu_extra_info "yq already installed"
    return
  fi

  ubuntu_extra_info "Installing yq..."
  local arch
  arch=$(dpkg --print-architecture)
  curl -Lo /tmp/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
  sudo install /tmp/yq /usr/local/bin/yq
  rm -f /tmp/yq
}

install_diff_so_fancy() {
  if command_exists diff-so-fancy; then
    ubuntu_extra_info "diff-so-fancy already installed"
    return
  fi

  ubuntu_extra_info "Installing diff-so-fancy..."
  sudo curl -Lo /usr/local/bin/diff-so-fancy "https://github.com/so-fancy/diff-so-fancy/releases/latest/download/diff-so-fancy"
  sudo chmod +x /usr/local/bin/diff-so-fancy
}

install_zoxide() {
  if command_exists zoxide; then
    ubuntu_extra_info "zoxide already installed"
    return
  fi

  ubuntu_extra_info "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

# ---------------------------------------------------------------------------
# Parity with the macOS Brewfile
#
# These have no apt package (or only a badly outdated one), so they are
# installed the same way Homebrew would give them on macOS.
# ---------------------------------------------------------------------------

install_atuin() {
  if command_exists atuin; then
    ubuntu_extra_info "atuin already installed"
    return
  fi

  ubuntu_extra_info "Installing atuin (shell history)..."
  # The installer probes /dev/tty under `set -e`; that exits early when this
  # bootstrap is run without a TTY. Explicitly select its supported CI mode.
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive \
    || ubuntu_extra_warn "atuin install script failed"
}

install_rust() {
  if command_exists cargo || command_exists rustc; then
    ubuntu_extra_info "Rust already installed"
    return
  fi

  # Ubuntu's rustc/cargo packages lag well behind; rustup is what the
  # Brewfile's `rust` formula effectively gives you on macOS.
  ubuntu_extra_info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path || ubuntu_extra_warn "rustup install failed"
}

install_awscli() {
  if command_exists aws; then
    ubuntu_extra_info "AWS CLI already installed"
    return
  fi

  local arch asset_url tmp_dir
  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64) asset_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
    aarch64 | arm64) asset_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
    *)
      ubuntu_extra_warn "No AWS CLI v2 installer for ${arch} — skipping"
      return 0
      ;;
  esac

  # awscli has no installation candidate on current Ubuntu 24.04 images.
  # Use Amazon's architecture-specific v2 bundle instead.
  tmp_dir="$(mktemp -d)"
  ubuntu_extra_info "Installing AWS CLI v2 (${arch})..."
  if curl -fsSL "${asset_url}" -o "${tmp_dir}/awscliv2.zip" \
    && unzip -q "${tmp_dir}/awscliv2.zip" -d "${tmp_dir}" \
    && sudo "${tmp_dir}/aws/install"; then
    ubuntu_extra_info "AWS CLI installed"
  else
    ubuntu_extra_warn "AWS CLI v2 installation failed"
  fi
  rm -rf "${tmp_dir}"
}

install_tealdeer() {
  # Asset is musl-static, so it runs on any glibc version.
  install_release_binary tldr tealdeer-rs/tealdeer \
    tealdeer-linux-x86_64-musl tealdeer-linux-aarch64-musl
}

install_hadolint() {
  install_release_binary hadolint hadolint/hadolint \
    hadolint-linux-x86_64 hadolint-linux-arm64
}

install_herdr() {
  install_release_binary herdr herdrdev/herdr \
    herdr-linux-x86_64 herdr-linux-aarch64
}

# ---------------------------------------------------------------------------
# Git-cloned tools
# ---------------------------------------------------------------------------

install_zsh_abbr() {
  local abbr_dir="${HOME}/.local/share/zsh-abbr"
  if [[ -d "${abbr_dir}" ]]; then
    ubuntu_extra_info "zsh-abbr already installed"
    return
  fi

  ubuntu_extra_info "Installing zsh-abbr via git clone..."
  git clone https://github.com/olets/zsh-abbr.git "${abbr_dir}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

ubuntu_extra_info "Installing Ubuntu extra packages..."

install_eza
install_gh
install_fish
install_starship
install_lazygit
install_lazydocker
install_uv
install_shfmt
install_yq
install_diff_so_fancy
install_zoxide
install_zsh_abbr

# Brewfile parity
install_atuin
install_rust
install_awscli
install_tealdeer
install_hadolint
install_herdr

ubuntu_extra_info "Ubuntu extra packages complete"
