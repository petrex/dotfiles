#!/usr/bin/env bats
# Each @test runs in its own subshell; per-test globals are intentional.
# shellcheck disable=SC2030,SC2031

# Tests for the optional agent skills prompt (Claude Code + Codex) in
# scripts/bootstrap.sh

load '../helpers/common.bash'

setup() {
  # Load bootstrap.sh functions without running main or installing its traps
  set --
  # shellcheck disable=SC1090
  source <(sed -e '/^main "\$@"$/d' -e '/^trap /d' "${BATS_TEST_DIRNAME}/../../scripts/bootstrap.sh")

  # Pretend a terminal is attached unless a test says otherwise
  # shellcheck disable=SC2329
  has_tty() { return 0; }
}

@test "plugin options include pstack and mattpocock skills" {
  # Arrange
  local all="${AGENT_PLUGIN_ENTRIES[*]}"

  # Assert
  assert_contains "${all}" "cursor-plugins:cursor/plugins:pstack@cursor-plugins:"
  assert_contains "${all}" "mattpocock:mattpocock/skills:mattpocock-skills@mattpocock:"
}

@test "choose_agent_skills selects nothing for either agent without a terminal" {
  # Arrange
  # shellcheck disable=SC2329
  has_tty() { return 1; }

  # Act
  choose_agent_skills </dev/null >/dev/null 2>&1

  # Assert
  assert_equals "false" "${INSTALL_GSTACK}"
  assert_equals "0" "${#SELECTED_PLUGIN_ENTRIES[@]}"
  assert_equals "false" "${INSTALL_GSTACK_CODEX}"
  assert_equals "0" "${#SELECTED_CODEX_PLUGIN_ENTRIES[@]}"
}

@test "choose_agent_skills asks Claude Code and Codex separately" {
  # Arrange: everything for Claude Code, nothing for Codex
  local answers
  answers=$(printf 'a\nn\n')

  # Act
  choose_agent_skills <<<"${answers}" >/dev/null 2>&1

  # Assert
  assert_equals "true" "${INSTALL_GSTACK}"
  assert_equals "${#AGENT_PLUGIN_ENTRIES[@]}" "${#SELECTED_PLUGIN_ENTRIES[@]}"
  assert_equals "false" "${INSTALL_GSTACK_CODEX}"
  assert_equals "0" "${#SELECTED_CODEX_PLUGIN_ENTRIES[@]}"
}

@test "choose_agent_skills installs nothing on 'n' for both agents" {
  # Act
  choose_agent_skills <<<"$(printf 'n\nn\n')" >/dev/null 2>&1

  # Assert
  assert_equals "false" "${INSTALL_GSTACK}"
  assert_equals "0" "${#SELECTED_PLUGIN_ENTRIES[@]}"
  assert_equals "false" "${INSTALL_GSTACK_CODEX}"
  assert_equals "0" "${#SELECTED_CODEX_PLUGIN_ENTRIES[@]}"
}

@test "choose_agent_skills asks per item on 'c' and defaults to no" {
  # Arrange: Claude Code: none. Codex: choose; gstack yes; first plugin yes;
  # the rest take the default (EOF)
  local answers
  answers=$(printf 'n\nc\ny\ny\n')

  # Act
  choose_agent_skills <<<"${answers}" >/dev/null 2>&1

  # Assert
  assert_equals "false" "${INSTALL_GSTACK}"
  assert_equals "0" "${#SELECTED_PLUGIN_ENTRIES[@]}"
  assert_equals "true" "${INSTALL_GSTACK_CODEX}"
  assert_equals "1" "${#SELECTED_CODEX_PLUGIN_ENTRIES[@]}"
  assert_equals "${AGENT_PLUGIN_ENTRIES[0]}" "${SELECTED_CODEX_PLUGIN_ENTRIES[0]}"
}

@test "install_claude_plugins does nothing when no plugin was selected" {
  # Arrange
  SELECTED_PLUGIN_ENTRIES=()
  # shellcheck disable=SC2329
  claude() { echo "claude called" >&2; return 1; }

  # Act
  local out
  out=$(install_claude_plugins 2>&1)

  # Assert
  assert_not_contains "${out}" "claude called"
}

@test "install_codex_plugins does nothing when no plugin was selected" {
  # Arrange
  SELECTED_CODEX_PLUGIN_ENTRIES=()
  # shellcheck disable=SC2329
  codex() { echo "codex called" >&2; return 1; }

  # Act
  local out
  out=$(install_codex_plugins 2>&1)

  # Assert
  assert_not_contains "${out}" "codex called"
}

@test "install_codex_plugins adds the marketplace and plugin for each selection" {
  # Arrange: a codex CLI that reports nothing installed yet
  SELECTED_CODEX_PLUGIN_ENTRIES=("${AGENT_PLUGIN_ENTRIES[3]}")
  # shellcheck disable=SC2329
  codex() { :; }
  # shellcheck disable=SC2329
  run_cmd() { printf '%s\n' "$1"; }

  # Act
  local out
  out=$(install_codex_plugins 2>&1)

  # Assert
  assert_contains "${out}" "codex plugin marketplace add 'cursor/plugins'"
  assert_contains "${out}" "codex plugin add 'pstack@cursor-plugins'"
}

@test "install_codex_plugins skips what is already installed" {
  # Arrange: codex lists the marketplace and plugin as present
  SELECTED_CODEX_PLUGIN_ENTRIES=("${AGENT_PLUGIN_ENTRIES[3]}")
  # shellcheck disable=SC2329
  codex() {
    case "$*" in
      "plugin marketplace list") printf 'MARKETPLACE  ROOT\ncursor-plugins  /x\n' ;;
      "plugin list") printf 'pstack@cursor-plugins  installed, enabled  0.1\n' ;;
    esac
  }
  # shellcheck disable=SC2329
  run_cmd() { printf 'RAN %s\n' "$1"; }
  DRY_RUN=false

  # Act
  local out
  out=$(install_codex_plugins 2>&1)

  # Assert
  assert_not_contains "${out}" "RAN"
}

@test "install_gstack runs the Codex host setup when only Codex selected it" {
  # Arrange
  INSTALL_GSTACK=false
  INSTALL_GSTACK_CODEX=true
  export DRY_RUN=true OS=macos

  # Act
  local out
  out=$(install_gstack 2>&1)

  # Assert
  assert_contains "${out}" "./setup --host codex"
  assert_not_contains "${out}" "Would run gstack ./setup for Claude Code"
}
