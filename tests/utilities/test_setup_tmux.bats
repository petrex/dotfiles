#!/usr/bin/env bats

# Tests for setup_tmux() in setup.sh (Tmux Plugin Manager install)

load '../helpers/common.bash'

setup() {
  export DOTFILES
  DOTFILES=$(mktemp -d)
  mkdir -p "${DOTFILES}/tmux/.config/tmux"

  # Load setup.sh functions without running main (clear bats' positional
  # args so setup.sh's option parser sees none)
  set --
  # shellcheck disable=SC1090
  source <(sed '/^main "\$@"$/d' "${BATS_TEST_DIRNAME}/../../setup.sh")

  # Record commands instead of executing them (overrides setup.sh's version)
  RUN_LOG="${DOTFILES}/run.log"
  # shellcheck disable=SC2329
  run_command() { printf '%s\n' "$1" >>"${RUN_LOG}"; }
  export DRY_RUN=false
}

teardown() {
  rm -rf "${DOTFILES}"
}

@test "setup_tmux clones TPM when tmux is not installed yet" {
  # Arrange: an empty PATH so `command -v tmux` fails, as on a fresh bootstrap
  local empty_bin="${DOTFILES}/bin"
  mkdir -p "${empty_bin}"

  # Act
  PATH="${empty_bin}" setup_tmux >/dev/null

  # Assert
  assert_contains "$(cat "${RUN_LOG}")" "git clone https://github.com/tmux-plugins/tpm"
}

@test "setup_tmux clones TPM when plugins dir exists without tpm" {
  # Arrange
  mkdir -p "${DOTFILES}/tmux/.config/tmux/plugins"

  # Act
  setup_tmux >/dev/null

  # Assert
  assert_contains "$(cat "${RUN_LOG}")" "tmux/.config/tmux/plugins/tpm"
}

@test "setup_tmux skips TPM clone when tpm is already installed" {
  # Arrange
  mkdir -p "${DOTFILES}/tmux/.config/tmux/plugins/tpm"

  # Act
  setup_tmux >/dev/null

  # Assert
  assert_not_contains "$(cat "${RUN_LOG}" 2>/dev/null)" "git clone"
}
