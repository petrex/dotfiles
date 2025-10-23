# Linux Support

Cross-platform dotfiles support for Ubuntu/Debian Linux systems.

## 📋 Overview

This directory contains Linux-specific configuration and bootstrap scripts that complement the main dotfiles repository, which was originally macOS-focused.

## 📁 Files

- **`bootstrap.sh`** - Main Linux bootstrap script (installs all dependencies)
- **`packages.list`** - APT package list (equivalent to macOS Brewfile)
- **`snap-packages.list`** - Snap package recommendations
- **`.linux.local.example`** - Local customization template
- **`README.md`** - This file

## 🚀 Quick Start

```bash
# 1. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# 2. Run bootstrap
cd ~/dotfiles
bash linux/bootstrap.sh 2>&1 | tee ~/linux-bootstrap.log

# 3. Run dotfiles setup
./setup.sh

# 4. Restart terminal
exec $SHELL
```

## 📚 Documentation

See the complete Linux setup guide: [docs/setup/linux-setup.md](../docs/setup/linux-setup.md)

## 🔄 Differences from macOS

| Feature | macOS | Linux |
|---------|-------|-------|
| Package Manager | Homebrew | APT (+ snap/flatpak) |
| Package List | `brew/Brewfile` | `linux/packages.list` |
| Bootstrap | `laptop/.laptop.local` | `linux/bootstrap.sh` |
| Local Config | `~/.laptop.local` | `~/.linux.local` |
| Package Prefix | `/opt/homebrew` or `/usr/local` | `/usr` |
| GUI Apps | Homebrew Casks | Snap/Flatpak/APT |

## 🎯 What Gets Installed

### Core Tools
- Git, GNU Stow, build-essential
- Zsh, Fish, Bash completion
- Tmux, Neovim
- ASDF version manager

### Modern CLI Tools
- bat (better cat)
- fd (better find)
- ripgrep (better grep)
- eza (better ls)
- zoxide (better cd)
- fzf (fuzzy finder)
- lazygit (git TUI)

### Development
- Development libraries (SSL, YAML, readline, etc.)
- Language support via ASDF:
  - Node.js
  - Ruby
  - Python
  - Lua
- Pre-commit framework
- Shellcheck

### Terminal
- Starship prompt
- Nerd Fonts symbols
- Cascadia Code, Fira Code, Hack fonts

## 🛠️ Customization

### Local Bootstrap Customization

```bash
# Copy template
cp linux/.linux.local.example ~/.linux.local

# Edit with your preferences
vim ~/.linux.local

# Run bootstrap (will source ~/.linux.local)
bash linux/bootstrap.sh
```

### Package Selection

Edit `linux/packages.list` to add/remove APT packages before running the bootstrap.

### GUI Applications

Linux uses multiple application distribution methods:

1. **APT packages** - System package manager
2. **Snap packages** - Universal packages (see `snap-packages.list`)
3. **Flatpak** - Alternative universal packages
4. **AppImage** - Portable applications

Choose the method that works best for your needs.

## 🔍 OS Detection

The dotfiles use `shared/os-detect.sh` to automatically detect the operating system and configure accordingly:

```bash
# Source OS detection
source ~/dotfiles/shared/os-detect.sh

# Check OS
if is_macos; then
  # macOS-specific code
elif is_ubuntu; then
  # Ubuntu-specific code
fi

# Get package manager
PKG_MANAGER=$(get_package_manager)  # Returns 'brew' or 'apt'
```

## 🧪 Testing

Test the bootstrap script in a VM or container first:

```bash
# Using Docker
docker run -it --rm ubuntu:22.04
apt update && apt install -y git
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
bash ~/dotfiles/linux/bootstrap.sh
```

## 📦 Package Management

### APT Packages

```bash
# Install from package list
sudo apt install $(grep -v '^#' linux/packages.list | xargs)

# Update packages
sudo apt update && sudo apt upgrade

# Search for package
apt search package-name
```

### Snap Packages

```bash
# Install snap package
sudo snap install package-name

# Install with classic confinement
sudo snap install --classic code

# List installed
snap list
```

### ASDF Languages

```bash
# Install Node.js
asdf install nodejs latest
asdf global nodejs latest

# Install Ruby
asdf install ruby latest
asdf global ruby latest
```

## 🆘 Troubleshooting

### Common Issues

1. **Command not found after install**
   - Reload shell: `exec $SHELL`
   - Check PATH: `echo $PATH`
   - Source profile: `source ~/.profile`

2. **bat/fd not found**
   - Create symlinks: 
     ```bash
     sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
     sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
     ```

3. **ASDF not working**
   - Add to shell config:
     ```bash
     echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
     ```

4. **Permission errors**
   - Fix ownership: `sudo chown -R $USER:$USER ~/dotfiles`
   - Make executable: `chmod +x linux/bootstrap.sh`

See full troubleshooting guide: [docs/setup/linux-setup.md#troubleshooting](../docs/setup/linux-setup.md#troubleshooting)

## 🔗 Resources

- [Complete Linux Setup Guide](../docs/setup/linux-setup.md)
- [Ubuntu Documentation](https://help.ubuntu.com/)
- [Debian Wiki](https://wiki.debian.org/)
- [ASDF Documentation](https://asdf-vm.com/)
- [Snap Store](https://snapcraft.io/store)
- [Flathub](https://flathub.org/)

## 💡 Tips

1. Run bootstrap on fresh system for best results
2. Review package lists before installing
3. Customize `.linux.local` for personal preferences
4. Use VM for testing before applying to main system
5. Keep system updated: `sudo apt update && sudo apt upgrade`
6. Back up existing configs before running setup

---

*Last updated: 2025-10-23*
