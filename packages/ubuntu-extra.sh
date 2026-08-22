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
# Desktop apps and fonts — the Brewfile `cask` section
#
# Ubuntu packages almost none of this. Only rclone and four plain font families
# come from apt (packages/apt-gui.txt); everything below needs a vendor apt
# repo or an upstream release. Gated on SKIP_GUI, exported by bootstrap.sh.
# ---------------------------------------------------------------------------

# Resolve one asset's download URL from a repo's latest release.
#
# Asset names cannot always be derived from the tag: ghostty-ubuntu tags
# `1.3.1-0-ppa2` but names the file `...1.3.1-0.ppa2...`, and source-code-pro's
# tag contains slashes. Ask the API for the URL instead of building it.
release_asset_url() {
  local repo="$1" pattern="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
    | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' \
    | sed -E 's/.*"(https:[^"]+)"$/\1/' \
    | grep -E "${pattern}" | head -1
}

# Read one field out of /etc/os-release without leaking the rest into the shell.
os_release_field() {
  (
    # shellcheck disable=SC1091
    . /etc/os-release 2>/dev/null || exit 0
    printf "%s" "${!1:-}"
  )
}

install_deb_url() {
  local name="$1" url="$2" tmp
  tmp="$(mktemp -d)"

  ubuntu_extra_info "Installing ${name}..."
  if curl -fsSL "${url}" -o "${tmp}/${name}.deb" \
    && sudo -E apt-get install -y "${tmp}/${name}.deb"; then
    ubuntu_extra_info "${name} installed"
  else
    ubuntu_extra_warn "Could not install ${name} from ${url}"
  fi
  rm -rf "${tmp}"
}

install_vscode() {
  if command_exists code; then
    ubuntu_extra_info "VS Code already installed"
    return
  fi

  ubuntu_extra_info "Installing VS Code via the Microsoft apt repository..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  sudo chmod 644 /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo -E apt-get update
  sudo -E apt-get install -y code || ubuntu_extra_warn "Could not install code"
}

install_ghostty() {
  if command_exists ghostty; then
    ubuntu_extra_info "Ghostty already installed"
    return
  fi

  # Ghostty ships no official .deb. mkasberg/ghostty-ubuntu builds one per
  # Ubuntu release; a deb built for a different release can pull in the wrong
  # glibc, so only take an exact VERSION_ID match.
  local arch version url
  arch="$(dpkg --print-architecture)"
  version="$(os_release_field VERSION_ID)"
  url="$(release_asset_url mkasberg/ghostty-ubuntu "_${arch}_${version}\.deb$")"

  if [[ -z "${url}" ]]; then
    ubuntu_extra_warn "No Ghostty build for Ubuntu ${version} ${arch}"
    ubuntu_extra_warn "  Check https://github.com/mkasberg/ghostty-ubuntu/releases"
    return
  fi

  install_deb_url ghostty "${url}"
}

install_zoom() {
  if command_exists zoom; then
    ubuntu_extra_info "Zoom already installed"
    return
  fi

  # Zoom publishes an amd64 .deb only — there is no arm64 Linux client.
  local arch
  arch="$(dpkg --print-architecture)"
  if [[ "${arch}" != "amd64" ]]; then
    ubuntu_extra_warn "Zoom has no ${arch} Linux client — skipping"
    return
  fi

  install_deb_url zoom "https://zoom.us/client/latest/zoom_amd64.deb"
}

install_tailscale() {
  if command_exists tailscale; then
    ubuntu_extra_info "Tailscale already installed"
    return
  fi

  local codename
  codename="$(os_release_field VERSION_CODENAME)"
  if [[ -z "${codename}" ]]; then
    ubuntu_extra_warn "Could not determine the Ubuntu codename — skipping Tailscale"
    return
  fi

  ubuntu_extra_info "Installing Tailscale via the vendor apt repository..."
  if ! curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null; then
    ubuntu_extra_warn "No Tailscale repository for ${codename} — skipping"
    return
  fi
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
    | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo -E apt-get update
  sudo -E apt-get install -y tailscale || ubuntu_extra_warn "Could not install tailscale"
}

install_moonlight() {
  if command_exists moonlight; then
    ubuntu_extra_info "Moonlight already installed"
    return
  fi

  # Upstream ships an AppImage (x86_64 only) and a Flatpak. The AppImage keeps
  # this dependency-free; adding Flatpak for one app is not worth it.
  local arch url
  arch="$(uname -m)"
  if [[ "${arch}" != "x86_64" ]]; then
    ubuntu_extra_warn "Moonlight publishes no ${arch} AppImage — skipping"
    return
  fi

  url="$(release_asset_url moonlight-stream/moonlight-qt 'x86_64\.AppImage$')"
  if [[ -z "${url}" ]]; then
    ubuntu_extra_warn "Could not resolve the latest Moonlight AppImage — skipping"
    return
  fi

  ubuntu_extra_info "Installing Moonlight (AppImage)..."
  if curl -fsSL "${url}" -o /tmp/moonlight.AppImage; then
    sudo install -m 755 /tmp/moonlight.AppImage /usr/local/bin/moonlight \
      || ubuntu_extra_warn "Could not install moonlight to /usr/local/bin"
  else
    ubuntu_extra_warn "Could not download the Moonlight AppImage"
  fi
  rm -f /tmp/moonlight.AppImage
}

# ---------------------------------------------------------------------------
# Fonts
#
# apt covers the plain Cascadia, Fira Code, Hack and JetBrains Mono families
# (see packages/apt-gui.txt). Every Nerd Font patch, plus Monaspace and Source
# Code Pro, has to come from upstream. Installed per-user under
# ~/.local/share/fonts so no sudo is involved.
# ---------------------------------------------------------------------------

FONTS_INSTALLED=false

# Usage: install_font_zip <dir-name> <owner/repo> <asset-regex> [size-note]
install_font_zip() {
  local name="$1" repo="$2" pattern="$3" note="${4:-}"
  local dest="${HOME}/.local/share/fonts/${name}"
  local url tmp

  if [[ -d "${dest}" ]] && [[ -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
    ubuntu_extra_info "${name} font already installed"
    return 0
  fi

  url="$(release_asset_url "${repo}" "${pattern}")"
  if [[ -z "${url}" ]]; then
    ubuntu_extra_warn "Could not resolve the ${name} font download — skipping"
    return 0
  fi

  ubuntu_extra_info "Installing the ${name} font${note}..."
  tmp="$(mktemp -d)"
  if curl -fsSL "${url}" -o "${tmp}/font.zip" \
    && unzip -qo "${tmp}/font.zip" -d "${tmp}/out"; then
    mkdir -p "${dest}"
    find "${tmp}/out" -type f \( -iname '*.ttf' -o -iname '*.otf' \) \
      -exec cp {} "${dest}/" \;
    FONTS_INSTALLED=true
  else
    ubuntu_extra_warn "Could not install the ${name} font"
  fi
  rm -rf "${tmp}"
}

install_fonts() {
  if ! command_exists unzip; then
    ubuntu_extra_warn "unzip not available — skipping the upstream fonts"
    return
  fi

  # Nerd Font patched families. The archives are large because each carries
  # every weight and both the Mono and Propo variants; the sizes are called out
  # so a multi-minute download does not look like a hang.
  install_font_zip CascadiaCodeNF ryanoasis/nerd-fonts '/CascadiaCode\.zip$' ' (~57 MB)'
  install_font_zip FiraCodeNF ryanoasis/nerd-fonts '/FiraCode\.zip$' ' (~29 MB)'
  install_font_zip HackNF ryanoasis/nerd-fonts '/Hack\.zip$' ' (~19 MB)'
  install_font_zip JetBrainsMonoNF ryanoasis/nerd-fonts '/JetBrainsMono\.zip$' ' (~134 MB)'
  install_font_zip MonaspiceNF ryanoasis/nerd-fonts '/Monaspace\.zip$' ' (~274 MB)'
  install_font_zip SymbolsNF ryanoasis/nerd-fonts '/NerdFontsSymbolsOnly\.zip$'

  # Unpatched families apt does not carry at all.
  install_font_zip Monaspace githubnext/monaspace '/monaspace-static-.*\.zip$' ' (~56 MB)'
  install_font_zip SourceCodePro adobe-fonts/source-code-pro '/TTF-source-code-pro.*\.zip$'

  if [[ "${FONTS_INSTALLED}" == "true" ]] && command_exists fc-cache; then
    ubuntu_extra_info "Rebuilding the font cache..."
    fc-cache -f "${HOME}/.local/share/fonts" >/dev/null 2>&1 \
      || ubuntu_extra_warn "fc-cache failed — new fonts may need a re-login"
  fi
}

# ---------------------------------------------------------------------------
# CLI agents distributed as macOS casks
# ---------------------------------------------------------------------------

install_codex() {
  if command_exists codex; then
    ubuntu_extra_info "Codex CLI already installed"
    return
  fi

  # cask "codex" on macOS. Use the npm channel OpenAI publishes; Phase 6 has
  # already provided node via asdf.
  if ! command_exists npm; then
    ubuntu_extra_warn "npm not available — skipping the Codex CLI"
    return
  fi

  ubuntu_extra_info "Installing the Codex CLI via npm..."
  npm install -g @openai/codex || ubuntu_extra_warn "Codex CLI install failed"
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
install_codex

# Desktop apps and fonts. SKIP_GUI is exported by bootstrap.sh Phase 8; default
# to installing them when this script is run on its own.
if [[ "${SKIP_GUI:-false}" == "true" ]]; then
  ubuntu_extra_info "Skipping desktop apps and fonts (--skip-gui)"
else
  install_vscode
  install_ghostty
  install_zoom
  install_tailscale
  install_moonlight
  install_fonts
fi

ubuntu_extra_info "Ubuntu extra packages complete"
