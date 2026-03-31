#!/usr/bin/env bats

# Tests for ai-fix (AI-powered error fix suggester)

load '../helpers/common.bash'
load '../helpers/shell_helpers.bash'

setup() {
  save_original_path
  setup_dotfiles_path
}

teardown() {
  restore_path
}

# Helper to remove claude from PATH
hide_claude() {
  export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "claude" | tr '\n' ':')
}

@test "ai-fix fails gracefully when claude CLI not installed" {
  hide_claude
  hash -r 2>/dev/null || true

  run bash -c 'echo "error" | ai-fix'
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "claude CLI not installed"
  assert_contains "${output}" "npm i -g"
}

@test "ai-fix shows usage when no stdin" {
  # Mock claude so the guard passes
  mock_command "claude" "mock fix"

  run ai-fix
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "Usage"
}

@test "ai-fix script is executable" {
  assert_file_exists "${DOTFILES}/bin/.local/bin/ai-fix"
  [ -x "${DOTFILES}/bin/.local/bin/ai-fix" ]
}

@test "ai-fix script has proper shebang" {
  local first_line
  first_line=$(head -1 "${DOTFILES}/bin/.local/bin/ai-fix")
  assert_equals "#!/usr/bin/env bash" "$first_line"
}
