#!/usr/bin/env bash
#
# cachyos-extra.sh — Install extra tools for CachyOS/Arch not in pacman repos
#
# This script is sourced by bootstrap.sh to install AUR or git-cloned tools
# on CachyOS/Arch systems.
#
# Usage: source packages/cachyos-extra.sh

set -e

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

cachyos_extra_info() {
  printf "[INFO] %s\n" "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Git-cloned tools
# ---------------------------------------------------------------------------

install_zsh_abbr() {
  local abbr_dir="${HOME}/.local/share/zsh-abbr"
  if [[ -d "${abbr_dir}" ]]; then
    cachyos_extra_info "zsh-abbr already installed"
    return
  fi

  cachyos_extra_info "Installing zsh-abbr via git clone..."
  git clone https://github.com/olets/zsh-abbr.git "${abbr_dir}"
}

# ---------------------------------------------------------------------------
# AUR packages (via yay or paru if available)
# ---------------------------------------------------------------------------

install_aur_package() {
  local pkg="$1"

  if pacman -Qi "${pkg}" &>/dev/null; then
    cachyos_extra_info "${pkg} already installed"
    return
  fi

  if command_exists yay; then
    cachyos_extra_info "Installing ${pkg} via yay..."
    yay -S --needed --noconfirm "${pkg}"
  elif command_exists paru; then
    cachyos_extra_info "Installing ${pkg} via paru..."
    paru -S --needed --noconfirm "${pkg}"
  else
    cachyos_extra_info "No AUR helper found — skipping ${pkg}"
  fi
}

install_uv() {
  if command_exists uv; then
    cachyos_extra_info "uv already installed"
    return
  fi

  cachyos_extra_info "Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

cachyos_extra_info "Installing CachyOS extra packages..."

install_zsh_abbr
install_uv

cachyos_extra_info "CachyOS extra packages complete"
