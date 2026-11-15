#!/usr/bin/env bats

# Tests for the optional Claude skills prompt in scripts/bootstrap.sh

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
  local all="${CLAUDE_PLUGIN_ENTRIES[*]}"

  # Assert
  assert_contains "${all}" "cursor-plugins:cursor/plugins:pstack@cursor-plugins:"
  assert_contains "${all}" "mattpocock:mattpocock/skills:mattpocock-skills@mattpocock:"
}

@test "choose_claude_skills selects nothing without a terminal" {
  # Arrange
  # shellcheck disable=SC2329
  has_tty() { return 1; }

  # Act
  choose_claude_skills </dev/null >/dev/null 2>&1

  # Assert
  assert_equals "false" "${INSTALL_GSTACK}"
  assert_equals "0" "${#SELECTED_PLUGIN_ENTRIES[@]}"
}

@test "choose_claude_skills installs everything on 'a'" {
  # Act
  choose_claude_skills <<<"a" >/dev/null 2>&1

  # Assert
  assert_equals "true" "${INSTALL_GSTACK}"
  assert_equals "${#CLAUDE_PLUGIN_ENTRIES[@]}" "${#SELECTED_PLUGIN_ENTRIES[@]}"
}

@test "choose_claude_skills installs nothing on 'n'" {
  # Act
  choose_claude_skills <<<"n" >/dev/null 2>&1

  # Assert
  assert_equals "false" "${INSTALL_GSTACK}"
  assert_equals "0" "${#SELECTED_PLUGIN_ENTRIES[@]}"
}

@test "choose_claude_skills asks per item on 'c' and defaults to no" {
  # Arrange: choose; gstack yes; first plugin yes; the rest take the default
  local answers
  answers=$(printf 'c\ny\ny\n')

  # Act
  choose_claude_skills <<<"${answers}" >/dev/null 2>&1

  # Assert
  assert_equals "true" "${INSTALL_GSTACK}"
  assert_equals "1" "${#SELECTED_PLUGIN_ENTRIES[@]}"
  assert_equals "${CLAUDE_PLUGIN_ENTRIES[0]}" "${SELECTED_PLUGIN_ENTRIES[0]}"
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
