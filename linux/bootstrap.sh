#!/usr/bin/env bash
#
# Linux (Ubuntu/Debian) Bootstrap Script
#
# Equivalent to the macOS laptop script, this sets up a fresh Linux system
# with all necessary tools for the dotfiles.
#
# Usage:
#   bash linux/bootstrap.sh 2>&1 | tee ~/linux-bootstrap.log
#
# This script is idempotent and can be run multiple times safely.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
fancy_echo() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "\\n${BLUE}==>${NC} ${fmt}\\n" "$@"
}

log_success() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "${GREEN}✓${NC} ${fmt}\\n" "$@"
}

log_error() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "${RED}✗${NC} ${fmt}\\n" "$@" >&2
}

log_warning() {
  local fmt="$1"
  shift
  # shellcheck disable=SC2059
  printf "${YELLOW}⚠${NC} ${fmt}\\n" "$@"
}

# Check if running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
  log_error "This script is for Linux systems only"
  exit 1
fi

# Check if running on Ubuntu/Debian
if [ ! -f /etc/os-release ]; then
  log_error "Cannot detect Linux distribution"
  exit 1
fi

. /etc/os-release
if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
  log_warning "This script is optimized for Ubuntu/Debian"
  log_warning "Current distribution: $NAME $VERSION"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

fancy_echo "Starting Linux bootstrap for $NAME $VERSION"

# Update package lists
fancy_echo "Updating package lists..."
sudo apt update

# Upgrade existing packages
fancy_echo "Upgrading existing packages..."
sudo apt upgrade -y

# Install essential build tools
fancy_echo "Installing build essentials..."
sudo apt install -y \
  build-essential \
  cmake \
  pkg-config \
  git \
  curl \
  wget \
  software-properties-common

log_success "Build essentials installed"

# Install core command-line tools
fancy_echo "Installing core command-line tools..."
sudo apt install -y \
  zsh \
  fish \
  tmux \
  neovim \
  vim \
  bash-completion \
  git-lfs \
  stow

log_success "Core tools installed"

# Install modern CLI replacements
fancy_echo "Installing modern CLI tools..."
sudo apt install -y \
  bat \
  fd-find \
  ripgrep \
  tree \
  htop \
  jq \
  zip \
  unzip \
  sqlite3

# Create symlinks for renamed packages
if [ ! -L /usr/local/bin/bat ]; then
  sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
fi
if [ ! -L /usr/local/bin/fd ]; then
  sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
fi

log_success "Modern CLI tools installed"

# Install development libraries
fancy_echo "Installing development libraries..."
sudo apt install -y \
  libssl-dev \
  libreadline-dev \
  libyaml-dev \
  libxml2-dev \
  libxslt1-dev \
  zlib1g-dev \
  libsqlite3-dev

log_success "Development libraries installed"

# Install optional tools
fancy_echo "Installing optional development tools..."
sudo apt install -y \
  shellcheck \
  yamllint \
  graphviz \
  telnet

log_success "Optional tools installed"

# Install Python (for pre-commit and other tools)
fancy_echo "Installing Python and pip..."
sudo apt install -y \
  python3 \
  python3-pip \
  python3-dev

# Install pre-commit
fancy_echo "Installing pre-commit framework..."
pip3 install --user pre-commit

log_success "Pre-commit installed"

# Install ASDF version manager
if [ ! -d "$HOME/.asdf" ]; then
  fancy_echo "Installing ASDF version manager..."
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
  log_success "ASDF installed"
else
  fancy_echo "ASDF already installed, updating..."
  cd ~/.asdf && git pull && cd -
  log_success "ASDF updated"
fi

# Source ASDF for this session
. "$HOME/.asdf/asdf.sh"

# Install ASDF plugins
fancy_echo "Installing ASDF plugins..."

# Node.js
if ! asdf plugin list | grep -q nodejs; then
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  log_success "Node.js plugin added"
fi

# Ruby
if ! asdf plugin list | grep -q ruby; then
  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
  log_success "Ruby plugin added"
fi

# Python
if ! asdf plugin list | grep -q python; then
  asdf plugin add python https://github.com/asdf-community/asdf-python.git
  log_success "Python plugin added"
fi

# Lua (for Neovim)
if ! asdf plugin list | grep -q lua; then
  asdf plugin add lua https://github.com/Stratus3D/asdf-lua.git
  log_success "Lua plugin added"
fi

# Install language versions if .tool-versions exists
if [ -f "$HOME/.tool-versions" ]; then
  fancy_echo "Installing language versions from .tool-versions..."
  asdf install
  log_success "Language versions installed"
fi

# Install Starship prompt
if ! command -v starship >/dev/null; then
  fancy_echo "Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
  log_success "Starship installed"
else
  fancy_echo "Starship already installed"
fi

# Install eza (modern ls replacement)
if ! command -v eza >/dev/null; then
  fancy_echo "Installing eza..."
  # Add eza repository
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt update
  sudo apt install -y eza
  log_success "eza installed"
else
  fancy_echo "eza already installed"
fi

# Install zoxide (better cd)
if ! command -v zoxide >/dev/null; then
  fancy_echo "Installing zoxide..."
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  log_success "zoxide installed"
else
  fancy_echo "zoxide already installed"
fi

# Install lazygit
if ! command -v lazygit >/dev/null; then
  fancy_echo "Installing lazygit..."
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit /usr/local/bin
  rm lazygit lazygit.tar.gz
  log_success "lazygit installed"
else
  fancy_echo "lazygit already installed"
fi

# Install fzf
if [ ! -d "$HOME/.fzf" ]; then
  fancy_echo "Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --all --no-bash --no-fish
  log_success "fzf installed"
else
  fancy_echo "fzf already installed"
fi

# Install fonts
fancy_echo "Installing fonts..."
sudo apt install -y \
  fonts-cascadia-code \
  fonts-firacode \
  fonts-hack

# Install Nerd Fonts (Symbols Only)
FONT_DIR="$HOME/.local/share/fonts"
if [ ! -f "$FONT_DIR/SymbolsNerdFont-Regular.ttf" ]; then
  fancy_echo "Installing Nerd Fonts symbols..."
  mkdir -p "$FONT_DIR"
  cd "$FONT_DIR"
  wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
  unzip -o NerdFontsSymbolsOnly.zip
  rm NerdFontsSymbolsOnly.zip
  fc-cache -fv
  cd -
  log_success "Nerd Fonts symbols installed"
else
  fancy_echo "Nerd Fonts already installed"
fi

# Setup PATH
fancy_echo "Configuring PATH..."
if ! grep -q '.local/bin' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
  log_success "Added ~/.local/bin to PATH"
fi

# Source local bootstrap if it exists
if [ -f "$HOME/.linux.local" ]; then
  fancy_echo "Running local bootstrap script..."
  # shellcheck disable=SC1091
  . "$HOME/.linux.local"
  log_success "Local bootstrap completed"
fi

# Clean up
fancy_echo "Cleaning up..."
sudo apt autoremove -y
sudo apt clean

# Summary
echo
fancy_echo "Linux bootstrap completed successfully!"
echo
echo "${GREEN}✓${NC} Core tools installed"
echo "${GREEN}✓${NC} Development libraries installed"
echo "${GREEN}✓${NC} ASDF version manager installed"
echo "${GREEN}✓${NC} Modern CLI tools installed"
echo "${GREEN}✓${NC} Fonts installed"
echo
echo "Next steps:"
echo "  1. Clone dotfiles: git clone https://github.com/yourusername/dotfiles.git ~/dotfiles"
echo "  2. Run setup: cd ~/dotfiles && ./setup.sh"
echo "  3. Install language versions: asdf install"
echo "  4. Restart your terminal or source: source ~/.profile"
echo
echo "For Fish shell:"
echo "  sudo chsh -s \$(which fish) \$(whoami)"
echo
echo "For Zsh shell:"
echo "  sudo chsh -s \$(which zsh) \$(whoami)"
echo

# vim: set filetype=sh:
