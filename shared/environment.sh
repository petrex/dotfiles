#!/usr/bin/env bash
#
# Shared environment variables for Zsh/Bash shell
# This file reduces duplication and ensures consistency across shells.
# Fish uses the parallel shared/environment.fish file.
#
# Usage:
#   Zsh/Bash:  source ~/dotfiles/shared/environment.sh in .zshrc/.bashrc

# Source OS detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/os-detect.sh"

# Editor configuration
export EDITOR="nvim"
export GIT_EDITOR="nvim"
export BUNDLER_EDITOR="${EDITOR}"

# Manual page configuration
export MANPAGER="less -X" # Don't clear the screen after quitting a manual page

# OS-specific configuration
if is_macos; then
  # Homebrew configuration (macOS only)
  export HOMEBREW_CASK_OPTS="--appdir=/Applications"
  
  # Ruby configuration with Homebrew paths
  export RUBY_CONFIGURE_OPTS="--with-opt-dir=${HOMEBREW_PREFIX}/opt/openssl:${HOMEBREW_PREFIX}/opt/readline:${HOMEBREW_PREFIX}/opt/libyaml:${HOMEBREW_PREFIX}/opt/gdbm"
else
  # Linux-specific configuration
  # Ruby configuration with system paths
  export RUBY_CONFIGURE_OPTS="--with-opt-dir=/usr"
fi

# Development configuration
export SOURCE_ANNOTATION_DIRECTORIES="spec"

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_STATE_HOME="${HOME}/.local/state"

# Dotfiles and configuration paths
export DOTFILES="${HOME}/dotfiles"
export RIPGREP_CONFIG_PATH="${HOME}/.ripgreprc"

# 1Password SSH agent (macOS)
if is_macos; then
  export SSH_AUTH_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi
# On Linux, 1Password SSH agent uses different path - see 1Password documentation

# Personal Knowledge Base
export PKB_PATH="${HOME}/personal-knowledge-base"

# FZF configuration
export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --no-ignore-vcs"
export FZF_DEFAULT_OPTS="--height 75% --layout=reverse --border"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd --type d . --color=never"
