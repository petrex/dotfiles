# Linux (Ubuntu/Debian) Setup Guide

Complete setup guide for installing and configuring dotfiles on Linux (Ubuntu/Debian) systems.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [OS-Specific Differences](#os-specific-differences)
- [Package Management](#package-management)
- [Troubleshooting](#troubleshooting)

## ✅ Prerequisites

### System Requirements

- Ubuntu 20.04 LTS or later (or Debian 11+)
- Internet connection
- Sudo/root access
- Git installed

### Minimum Specifications

- 2GB RAM
- 10GB free disk space
- x86_64 (AMD64) or ARM64 architecture

## 🚀 Quick Start

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install git if needed
sudo apt install -y git curl

# 3. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# 4. Run Linux bootstrap
cd ~/dotfiles
bash linux/bootstrap.sh 2>&1 | tee ~/linux-bootstrap.log

# 5. Run dotfiles setup
./setup.sh

# 6. Restart terminal
exec $SHELL
```

## 📚 Detailed Installation

### Step 1: System Preparation

```bash
# Update package lists
sudo apt update

# Upgrade existing packages
sudo apt upgrade -y

# Install basic requirements
sudo apt install -y git curl wget build-essential
```

### Step 2: Run Bootstrap Script

The bootstrap script installs all necessary tools and dependencies:

```bash
cd ~/dotfiles
bash linux/bootstrap.sh 2>&1 | tee ~/linux-bootstrap.log
```

**What the bootstrap script installs:**

- **Core Tools**: Git, Zsh, Fish, Tmux, Neovim, GNU Stow
- **Modern CLI**: bat, fd, ripgrep, eza, zoxide, fzf
- **Development Libraries**: OpenSSL, readline, YAML, XML, SQLite
- **Version Managers**: ASDF (Node.js, Ruby, Python, Lua)
- **Utilities**: Starship prompt, lazygit, pre-commit
- **Fonts**: Cascadia Code, Fira Code, Hack, Nerd Fonts Symbols

### Step 3: Customize Local Bootstrap (Optional)

Before running the bootstrap, customize it for your needs:

```bash
# Copy local configuration template
cp linux/.linux.local.example ~/.linux.local

# Edit with your preferences
vim ~/.linux.local
```

Add custom packages, PPAs, or configuration in `.linux.local`.

### Step 4: Run Dotfiles Setup

```bash
cd ~/dotfiles

# Preview what will be done
./setup.sh --dry-run

# Run actual setup
./setup.sh
```

This will:
- Create necessary directories
- Symlink configuration files with GNU Stow
- Setup shell integration
- Configure tmux plugins

### Step 5: Install Additional Packages

```bash
# Install packages from list
sudo apt install $(grep -v '^#' ~/dotfiles/linux/packages.list | xargs)

# Or install selectively by category
# See linux/packages.list for organized categories
```

### Step 6: Setup Languages with ASDF

```bash
# Node.js
asdf install nodejs latest
asdf global nodejs latest

# Ruby
asdf install ruby latest
asdf global ruby latest

# Python
asdf install python latest
asdf global python latest

# Lua (for Neovim)
asdf install lua latest
asdf global lua latest
```

### Step 7: Configure Shell

Choose your preferred shell:

```bash
# Fish shell
sudo chsh -s $(which fish) $(whoami)

# or Zsh shell
sudo chsh -s $(which zsh) $(whoami)

# Install Zsh plugin manager (if using Zsh)
# See: https://www.zapzsh.com
```

### Step 8: Setup Git Hooks

```bash
cd ~/dotfiles
./scripts/setup-git-hooks.sh
```

### Step 9: Configure Neovim

```bash
# Launch Neovim (plugins auto-install)
nvim

# Run health check
:checkhealth

# Update plugins
:Lazy update
```

## 🔄 OS-Specific Differences

### Package Managers

| macOS | Linux |
|-------|-------|
| Homebrew (`brew`) | APT (`apt`) |
| `brew install package` | `sudo apt install package` |
| `brew/Brewfile` | `linux/packages.list` |

### Path Differences

| Type | macOS | Linux |
|------|-------|-------|
| Package prefix | `/opt/homebrew` or `/usr/local` | `/usr` |
| User binaries | `~/.local/bin` | `~/.local/bin` |
| Config directory | `~/.config` | `~/.config` |

### GUI Applications

**macOS:** Installed via Homebrew Casks

```bash
brew install --cask firefox
```

**Linux:** Use snap, flatpak, or apt

```bash
# Snap
sudo snap install firefox

# Flatpak
flatpak install flathub org.mozilla.firefox

# APT (if available)
sudo apt install firefox
```

### Fonts

**macOS:** Installed via Homebrew Cask Fonts

**Linux:** Installed via apt or manual installation

```bash
# Via APT
sudo apt install fonts-firacode

# Manual installation
mkdir -p ~/.local/share/fonts
# Download and extract fonts to ~/.local/share/fonts
fc-cache -fv
```

## 📦 Package Management

### APT Packages

```bash
# List installed packages
linux/packages.list

# Install all packages
sudo apt install $(grep -v '^#' linux/packages.list | xargs)

# Search for package
apt search package-name

# Show package info
apt show package-name
```

### Snap Packages

```bash
# See available snap packages
cat linux/snap-packages.list

# Install snap package
sudo snap install package-name

# Install with classic confinement
sudo snap install --classic package-name

# List installed snaps
snap list
```

### Flatpak (Optional)

```bash
# Install flatpak
sudo apt install -y flatpak

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install application
flatpak install flathub com.app.name

# List installed apps
flatpak list
```

### ASDF Version Manager

```bash
# List plugins
asdf plugin list

# Install version
asdf install nodejs 20.10.0

# Set global version
asdf global nodejs 20.10.0

# Set local version (for project)
asdf local nodejs 18.19.0

# List installed versions
asdf list nodejs
```

## 🔧 Configuration Files

### Linux-Specific Files

- `linux/bootstrap.sh` - Main bootstrap script
- `linux/packages.list` - APT packages
- `linux/snap-packages.list` - Snap packages
- `linux/.linux.local.example` - Local customization template

### Shared Configuration

These work on both macOS and Linux:
- `shared/abbreviations.yaml` - Shell abbreviations
- `shared/environment.sh` - Environment variables
- `shared/os-detect.sh` - OS detection utility
- All shell configurations (Fish, Zsh)
- Neovim configuration
- Tmux configuration
- Git configuration

## 🆘 Troubleshooting

### Bootstrap Script Fails

**Problem:** Bootstrap script errors or doesn't complete

**Solutions:**

```bash
# Run with verbose output
bash -x linux/bootstrap.sh 2>&1 | tee ~/bootstrap-debug.log

# Check prerequisites
which git curl wget sudo

# Verify internet connection
curl -I https://github.com

# Check available disk space
df -h ~
```

### Package Installation Fails

**Problem:** APT packages fail to install

**Solutions:**

```bash
# Update package lists
sudo apt update

# Fix broken dependencies
sudo apt --fix-broken install

# Clean package cache
sudo apt clean
sudo apt autoclean

# Retry with specific package
sudo apt install -y package-name
```

### Command Not Found After Install

**Problem:** Installed commands not found in PATH

**Solutions:**

```bash
# Check if binary exists
which command-name
ls -la /usr/bin/command-name
ls -la ~/.local/bin/command-name

# Reload PATH
source ~/.profile
source ~/.bashrc  # or ~/.zshrc

# Add to PATH manually
export PATH="$HOME/.local/bin:$PATH"

# Make permanent
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
```

### Symlinks for bat/fd Not Working

**Problem:** `bat` or `fd` commands not found

**Solutions:**

```bash
# Create symlinks manually
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Or use the full names
batcat --version
fdfind --version
```

### ASDF Not Working

**Problem:** ASDF commands not found

**Solutions:**

```bash
# Check ASDF installation
ls -la ~/.asdf

# Add to shell configuration
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc

# For Fish
mkdir -p ~/.config/fish/conf.d
echo 'source ~/.asdf/asdf.fish' > ~/.config/fish/conf.d/asdf.fish

# Reload shell
exec $SHELL
```

### Starship Prompt Not Showing

**Problem:** Starship prompt doesn't appear

**Solutions:**

```bash
# Check installation
which starship
starship --version

# Add to shell config
# For Bash
echo 'eval "$(starship init bash)"' >> ~/.bashrc

# For Zsh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# For Fish
echo 'starship init fish | source' >> ~/.config/fish/config.fish

# Reload shell
exec $SHELL
```

### Permission Denied Errors

**Problem:** Permission errors during setup

**Solutions:**

```bash
# Check file ownership
ls -la ~/dotfiles

# Fix ownership
sudo chown -R $USER:$USER ~/dotfiles

# Make scripts executable
chmod +x ~/dotfiles/setup.sh
chmod +x ~/dotfiles/scripts/*
chmod +x ~/dotfiles/linux/bootstrap.sh
```

### Fonts Not Rendering

**Problem:** Nerd font icons not displaying

**Solutions:**

```bash
# Install font dependencies
sudo apt install -y fontconfig

# Reinstall Nerd Fonts
rm -rf ~/.local/share/fonts/NerdFonts*
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
unzip NerdFontsSymbolsOnly.zip
rm NerdFontsSymbolsOnly.zip

# Rebuild font cache
fc-cache -fv

# Verify installation
fc-list | grep "Symbols Nerd Font"

# Configure terminal to use the font
# This varies by terminal emulator
```

## 💡 Tips

1. **Use sudo sparingly** - Most configuration doesn't need root
2. **Keep system updated** - Run `sudo apt update && sudo apt upgrade` regularly
3. **Test in VM first** - Try the setup in a virtual machine before main system
4. **Backup first** - Back up existing configs before running setup
5. **Read the logs** - Check bootstrap and setup logs for warnings
6. **Start fresh** - Consider using the bootstrap on a fresh install for best results
7. **Customize gradually** - Start with defaults, then customize incrementally

## 📚 Additional Resources

- [Ubuntu Documentation](https://help.ubuntu.com/)
- [Debian Wiki](https://wiki.debian.org/)
- [ASDF Documentation](https://asdf-vm.com/guide/getting-started.html)
- [Fish Shell Tutorial](https://fishshell.com/docs/current/tutorial.html)
- [Zsh User Guide](https://zsh.sourceforge.io/Guide/)
- [Neovim Documentation](https://neovim.io/doc/)
- [Starship Configuration](https://starship.rs/config/)

---

*Last updated: 2025-10-23*
