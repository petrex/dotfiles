#!/usr/bin/env bats

# Tests for ai-commit (AI-powered commit message generator)

load '../helpers/common.bash'
load '../helpers/git_helpers.bash'
load '../helpers/shell_helpers.bash'

setup() {
  save_original_path
  setup_dotfiles_path
}

teardown() {
  teardown_test_git_repo
  restore_path
  # Clean up any mock claude
  if [[ -n "${MOCK_CLAUDE_DIR:-}" ]]; then
    rm -rf "$MOCK_CLAUDE_DIR"
  fi
}

# Helper to remove claude from PATH for guard clause tests
hide_claude() {
  MOCK_CLAUDE_DIR=$(mktemp -d)
  # Create a PATH without claude
  export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "claude" | tr '\n' ':')
}

@test "ai-commit fails gracefully when claude CLI not installed" {
  hide_claude
  # Also ensure no mock claude exists
  hash -r 2>/dev/null || true

  run ai-commit
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "claude CLI not installed"
  assert_contains "${output}" "npm i -g"
}

@test "ai-commit fails when no staged changes" {
  setup_main_repo

  # Mock claude so the guard passes
  mock_command "claude" "mock commit message"

  run ai-commit
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "No staged changes"
}

@test "ai-commit script is executable" {
  assert_file_exists "${DOTFILES}/bin/.local/bin/ai-commit"
  [ -x "${DOTFILES}/bin/.local/bin/ai-commit" ]
}

@test "ai-commit script has proper shebang" {
  local first_line
  first_line=$(head -1 "${DOTFILES}/bin/.local/bin/ai-commit")
  assert_equals "#!/usr/bin/env bash" "$first_line"
}
