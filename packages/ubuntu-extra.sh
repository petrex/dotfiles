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

  ubuntu_extra_info "Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
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

ubuntu_extra_info "Ubuntu extra packages complete"
