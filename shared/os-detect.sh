#!/usr/bin/env bash
#
# OS Detection Utility
#
# Provides functions for detecting operating system and setting appropriate
# environment variables for cross-platform dotfiles support.
#
# Usage:
#   source ~/dotfiles/shared/os-detect.sh
#   if is_macos; then
#     # macOS-specific code
#   elif is_linux; then
#     # Linux-specific code
#   fi

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      # Detect Linux distribution
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu | debian)
            echo "ubuntu"
            ;;
          fedora | rhel | centos)
            echo "fedora"
            ;;
          arch | manjaro)
            echo "arch"
            ;;
          *)
            echo "linux"
            ;;
        esac
      else
        echo "linux"
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Check if running on macOS
is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

# Check if running on Linux
is_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

# Check if running on Ubuntu/Debian
is_ubuntu() {
  if is_linux && [ -f /etc/os-release ]; then
    . /etc/os-release
    [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]
  else
    return 1
  fi
}

# Check if running on Fedora/RHEL
is_fedora() {
  if is_linux && [ -f /etc/os-release ]; then
    . /etc/os-release
    [[ "$ID" == "fedora" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "centos" ]]
  else
    return 1
  fi
}

# Check if running on Arch Linux
is_arch() {
  if is_linux && [ -f /etc/os-release ]; then
    . /etc/os-release
    [[ "$ID" == "arch" ]] || [[ "$ID" == "manjaro" ]]
  else
    return 1
  fi
}

# Get package manager for current OS
get_package_manager() {
  if is_macos; then
    echo "brew"
  elif is_ubuntu; then
    echo "apt"
  elif is_fedora; then
    echo "dnf"
  elif is_arch; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Get default shell configuration directory
get_shell_config_dir() {
  echo "${HOME}/.config"
}

# Get package manager prefix path
get_package_prefix() {
  if is_macos; then
    if [[ "$(uname -m)" == "arm64" ]]; then
      echo "/opt/homebrew"
    else
      echo "/usr/local"
    fi
  else
    echo "/usr"
  fi
}

# Export OS-specific environment variables
export_os_env() {
  export OS_TYPE="$(detect_os)"
  export PKG_MANAGER="$(get_package_manager)"
  export PKG_PREFIX="$(get_package_prefix)"
  
  if is_macos; then
    export HOMEBREW_PREFIX="$(get_package_prefix)"
  fi
}

# Print OS information
print_os_info() {
  echo "Operating System: $(detect_os)"
  echo "Package Manager: $(get_package_manager)"
  echo "Package Prefix: $(get_package_prefix)"
  
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Distribution: $NAME $VERSION"
  fi
}

# Initialize if sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being run directly
  print_os_info
else
  # Script is being sourced
  export_os_env
fi

# vim: set filetype=sh:
