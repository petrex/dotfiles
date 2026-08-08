#!/usr/bin/env bash

set -e

################################################################################
# Configure user-owned state that is not represented by Stow symlinks.
#
# This script never uses sudo or changes system settings, but it may access the
# network to install Tmux Plugin Manager.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
DRY_RUN=false

info() {
  printf '[USER SETUP] %s\n' "$*"
}

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Configure user-owned state that cannot be managed by Stow:
  - Fish universal paths
  - User terminfo entries
  - Tmux Plugin Manager

This command does not use sudo or modify system settings. It may clone TPM
from GitHub when tmux is installed and TPM is missing.

Options:
  --dry-run    Show what would be done without making changes or using network
  --help       Show this help message
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        show_help >&2
        exit 1
        ;;
    esac
    shift
  done
}

setup_shell_integration() {
  if ! command -v fish >/dev/null 2>&1; then
    info "Fish not found; skipping universal path configuration"
    return
  fi

  local paths=(
    "${HOME}/.asdf/shims"
    "${HOME}/.local/bin"
    "${HOME}/.bin"
    "${HOME}/.yarn/bin"
  )

  if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
      paths+=("/opt/homebrew/bin")
    else
      paths+=("/usr/local/bin")
    fi
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would set Fish universal paths: ${paths[*]}"
  else
    info "Setting Fish universal paths"
    # Do not add --no-config: it isolates the universal variable store, so
    # `set -U` would not persist to the user's real fish_variables file.
    # Fish expands $argv; Bash must pass the expression through unchanged.
    # shellcheck disable=SC2016
    command fish -c 'set -U fish_user_paths $argv' "${paths[@]}"
  fi
}

setup_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    info "Tmux not found; skipping terminfo and plugin setup"
    return
  fi

  if [[ ! -d "${HOME}/.terminfo" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      info "[DRY RUN] Would compile custom terminfo entries into ${HOME}/.terminfo"
    else
      info "Compiling custom terminfo entries"
      tic -x "${DOTFILES}/terminfo/tmux-256color.terminfo"
      tic -x "${DOTFILES}/terminfo/xterm-256color-italic.terminfo"
    fi
  else
    info "User terminfo directory already exists"
  fi

  local tpm_dir="${DOTFILES}/tmux/.config/tmux/plugins/tpm"
  if [[ -d "${tpm_dir}" ]]; then
    info "Tmux Plugin Manager already installed"
  elif [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] Would clone Tmux Plugin Manager to ${tpm_dir}"
  else
    info "Installing Tmux Plugin Manager"
    mkdir -p "$(dirname "${tpm_dir}")"
    git clone https://github.com/tmux-plugins/tpm "${tpm_dir}"
  fi
}

main() {
  parse_args "$@"

  if [[ ! -d "${DOTFILES}" ]]; then
    printf 'Dotfiles directory not found: %s\n' "${DOTFILES}" >&2
    exit 1
  fi

  setup_shell_integration
  setup_tmux
  info "User setup complete"
}

main "$@"
