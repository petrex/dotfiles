#!/usr/bin/env bash

set -e

################################################################################
# Apply optional machine-wide settings.
#
# This is the only setup phase that may request administrator access. Never run
# the entire script as root; individual commands use sudo when required.
################################################################################

DRY_RUN=false

info() {
  printf '[SYSTEM SETUP] %s\n' "$*"
}

show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Apply optional machine-wide settings. On macOS this synchronizes HostName and
the SMB NetBIOSName with the existing LocalHostName. No Linux system settings
are currently managed.

This command may request administrator access. Do not run it with sudo.

Options:
  --dry-run    Show the planned system changes without requesting sudo
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

setup_macos_hostname() {
  local computer_name local_host_name
  computer_name="$(scutil --get ComputerName)"
  local_host_name="$(scutil --get LocalHostName)"

  printf 'System changes requested:\n\n'
  printf '  - Set HostName to %s\n' "${local_host_name}"
  printf '  - Set SMB NetBIOSName to %s\n\n' "${local_host_name}"
  printf 'ComputerName:  %s\n' "${computer_name}"
  printf 'LocalHostName: %s\n' "${local_host_name}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[DRY RUN] No administrator access requested"
    return
  fi

  info "Requesting administrator access for the listed system changes"
  sudo -v
  sudo scutil --set HostName "${local_host_name}"
  sudo defaults write \
    /Library/Preferences/SystemConfiguration/com.apple.smb.server.plist \
    NetBIOSName -string "${local_host_name}"
  info "HostName and SMB NetBIOSName updated"
}

main() {
  parse_args "$@"

  if ((EUID == 0)) && [[ "${DRY_RUN}" == "false" ]]; then
    printf 'Do not run this script as root; it invokes sudo only when required.\n' >&2
    exit 1
  fi

  case "$(uname)" in
    Darwin)
      setup_macos_hostname
      ;;
    Linux)
      info "No Linux system settings are currently managed; nothing to do"
      ;;
    *)
      printf 'Unsupported operating system: %s\n' "$(uname)" >&2
      exit 1
      ;;
  esac

  info "System setup complete"
}

main "$@"
