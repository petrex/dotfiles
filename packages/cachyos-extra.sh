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
# AUR helper
#
# yay (https://github.com/jguer/yay) is not in the Arch repos -- it lives in
# the AUR itself, so installing it is a small bootstrap problem of its own.
# CachyOS ships it in the `cachyos` repo, so pacman handles it there; plain
# Arch has to build it.
#
# Without a helper, install_aur_package() can only skip: VS Code silently
# degrades to Code - OSS and Zoom is not installed at all.
# ---------------------------------------------------------------------------

install_yay() {
  if command_exists yay; then
    cachyos_extra_info "yay already installed"
    return 0
  fi

  if command_exists paru; then
    cachyos_extra_info "paru is already present -- not installing yay as well"
    return 0
  fi

  # CachyOS carries yay in its own repo; on plain Arch this simply fails.
  if sudo pacman -S --needed --noconfirm yay >/dev/null 2>&1; then
    cachyos_extra_info "yay installed from the distro repos"
    return 0
  fi

  # makepkg refuses to run as root by design.
  if [[ "${EUID}" -eq 0 ]]; then
    cachyos_extra_warn "Cannot build yay as root -- re-run the bootstrap as a normal user"
    return 0
  fi

  if ! command_exists makepkg; then
    cachyos_extra_warn "makepkg not found (base-devel missing) -- cannot build yay"
    return 0
  fi

  # yay-bin ships a prebuilt binary. Building `yay` from source would pull the
  # entire Go toolchain (makedepends go>=1.24) in for a single tool.
  local build_dir
  build_dir="$(mktemp -d)"
  cachyos_extra_info "Building yay-bin from the AUR..."
  if git clone -q --depth 1 https://aur.archlinux.org/yay-bin.git "${build_dir}/yay-bin" \
    && (cd "${build_dir}/yay-bin" && makepkg -si --noconfirm --needed); then
    cachyos_extra_info "yay installed"
  else
    cachyos_extra_warn "Could not build yay -- AUR packages will be skipped"
  fi
  rm -rf "${build_dir}"

  return 0
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
    cachyos_extra_warn "No AUR helper (yay/paru) found — skipping ${pkg}"
    return 1
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
# Desktop apps — the Brewfile `cask` entries that the official repos lack
#
# ghostty, tailscale, moonlight-qt, rclone and every font come from
# packages/pacman-gui.txt. Only these two need the AUR.
# ---------------------------------------------------------------------------

install_vscode() {
  if command_exists code; then
    cachyos_extra_info "VS Code already installed"
    return
  fi

  # The Brewfile installs Microsoft's build, which lives in the AUR. The `code`
  # package in extra is Code - OSS: same editor, but no Marketplace, no
  # Settings Sync and no telemetry-bearing MS branding. Prefer the real thing,
  # fall back to OSS rather than leaving the machine with no editor.
  if install_aur_package visual-studio-code-bin; then
    return
  fi

  cachyos_extra_warn "Falling back to Code - OSS (no Marketplace or Settings Sync)"
  sudo pacman -S --needed --noconfirm code \
    || cachyos_extra_warn "Could not install code"
}

install_zoom() {
  if command_exists zoom; then
    cachyos_extra_info "Zoom already installed"
    return
  fi

  # AUR only — Zoom ships no Arch package and no official repo.
  install_aur_package zoom \
    || cachyos_extra_warn "Install Zoom manually: https://zoom.us/download?os=linux"
}

# ---------------------------------------------------------------------------
# CLI agents distributed as macOS casks
# ---------------------------------------------------------------------------

install_codex() {
  if command_exists codex; then
    cachyos_extra_info "Codex CLI already installed"
    return
  fi

  # cask "codex" on macOS. The AUR package has almost no adoption, so use the
  # npm channel OpenAI publishes; Phase 6 has already provided node via asdf.
  if ! command_exists npm; then
    cachyos_extra_warn "npm not available — skipping the Codex CLI"
    return
  fi

  cachyos_extra_info "Installing the Codex CLI via npm..."
  if ! npm install -g @openai/codex; then
    cachyos_extra_warn "Codex CLI install failed"
    return
  fi

  # asdf's npm shim reshims itself after a global install, so the binary does
  # land on PATH -- but only once this shell re-scans it.
  hash -r 2>/dev/null || true

  # Report from what is actually resolvable, not from npm's exit status.
  if command_exists codex; then
    cachyos_extra_info "Codex CLI installed at $(command -v codex)"
  else
    cachyos_extra_warn "Codex CLI installed but is not on PATH."
    cachyos_extra_warn "  If node came from asdf, open a new shell or run: asdf reshim nodejs"
  fi
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
install_codex

# Desktop apps. SKIP_GUI is exported by bootstrap.sh Phase 8; default to
# installing them when this script is run on its own.
if [[ "${SKIP_GUI:-false}" == "true" ]]; then
  cachyos_extra_info "Skipping desktop apps (--skip-gui)"
else
  # Must precede the AUR installs below -- they are no-ops without a helper.
  install_yay
  install_vscode
  install_zoom
fi

cachyos_extra_info "CachyOS extra packages complete"
