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

cachyos_extra_warn() {
  printf "[WARN] %s\n" "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install a static binary from a GitHub release.
#
# hadolint and herdr are in the Brewfile but are not in the Arch repos, and
# their AUR packages need an AUR helper that may not be present. Their upstream
# Linux binaries give the same tools without that dependency.
#
# Usage: install_release_binary <command> <owner/repo> <asset-x86_64> <asset-arm64>
install_release_binary() {
  local cmd="$1" repo="$2" asset_x86="$3" asset_arm="$4"
  local asset arch tag url

  if command_exists "${cmd}"; then
    cachyos_extra_info "${cmd} already installed"
    return 0
  fi

  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64) asset="${asset_x86}" ;;
    aarch64 | arm64) asset="${asset_arm}" ;;
    *)
      cachyos_extra_warn "No ${cmd} release binary for ${arch} — skipping"
      return 0
      ;;
  esac

  tag="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
    | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)" || true
  if [[ -z "${tag}" ]]; then
    cachyos_extra_warn "Could not resolve the latest ${cmd} release — skipping"
    return 0
  fi

  url="https://github.com/${repo}/releases/download/${tag}/${asset}"
  cachyos_extra_info "Installing ${cmd} ${tag} (${arch})..."
  if ! curl -fsSL -o "/tmp/${cmd}.bin" "${url}"; then
    cachyos_extra_warn "Could not download ${url} — skipping ${cmd}"
    rm -f "/tmp/${cmd}.bin"
    return 0
  fi

  sudo install -m 755 "/tmp/${cmd}.bin" "/usr/local/bin/${cmd}" \
    || cachyos_extra_warn "Could not install ${cmd} to /usr/local/bin"
  rm -f "/tmp/${cmd}.bin"
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
  # zsh-abbr depends on the zsh-job-queue submodule; without it the plugin
  # prints "There was a problem finishing installing dependencies" on load.
  if [[ -d "${abbr_dir}" ]]; then
    if [[ ! -f "${abbr_dir}/zsh-job-queue/zsh-job-queue.zsh" ]]; then
      cachyos_extra_info "zsh-abbr present but missing submodules — initializing..."
      git -C "${abbr_dir}" submodule update --init --recursive
    else
      cachyos_extra_info "zsh-abbr already installed"
    fi
    return
  fi

  cachyos_extra_info "Installing zsh-abbr via git clone..."
  git clone --recurse-submodules https://github.com/olets/zsh-abbr.git "${abbr_dir}"
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

# Brewfile parity — not in the Arch repos
install_hadolint
install_herdr

cachyos_extra_info "CachyOS extra packages complete"
