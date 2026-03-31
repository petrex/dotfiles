#!/usr/bin/env bats

# Tests for ai-explain (AI-powered command output explainer)

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

@test "ai-explain fails gracefully when claude CLI not installed" {
  hide_claude
  hash -r 2>/dev/null || true

  run bash -c 'echo "test" | ai-explain'
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "claude CLI not installed"
  assert_contains "${output}" "npm i -g"
}

@test "ai-explain shows usage when no stdin" {
  # Mock claude so the guard passes
  mock_command "claude" "mock explanation"

  run ai-explain
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "Usage"
}

@test "ai-explain script is executable" {
  assert_file_exists "${DOTFILES}/bin/.local/bin/ai-explain"
  [ -x "${DOTFILES}/bin/.local/bin/ai-explain" ]
}

@test "ai-explain script has proper shebang" {
  local first_line
  first_line=$(head -1 "${DOTFILES}/bin/.local/bin/ai-explain")
  assert_equals "#!/usr/bin/env bash" "$first_line"
}
