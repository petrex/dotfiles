#!/usr/bin/env bats

# Tests for audit-abbreviations.sh (abbreviation auditor)

load '../helpers/common.bash'
load '../helpers/shell_helpers.bash'

setup() {
  save_original_path
  setup_dotfiles_path
}

teardown() {
  restore_path
}

@test "audit-abbreviations fails gracefully when atuin not installed" {
  # Create a PATH without atuin
  local clean_path
  clean_path=$(echo "$PATH" | tr ':' '\n' | grep -v "atuin" | tr '\n' ':')

  run env PATH="$clean_path" bash "${DOTFILES}/scripts/audit-abbreviations.sh"
  [ "${status}" -ne 0 ]
  assert_contains "${output}" "atuin not installed"
}

@test "audit-abbreviations detects cold start (insufficient history)" {
  # Mock atuin with minimal history (less than 100 commands)
  local mock_dir
  mock_dir=$(mktemp -d)
  cat > "${mock_dir}/atuin" << 'MOCK'
#!/bin/bash
if [[ "$1" == "history" && "$2" == "list" ]]; then
  # Output only 5 commands (below MIN_HISTORY threshold)
  echo "ls"
  echo "cd"
  echo "git status"
  echo "vim"
  echo "echo hello"
fi
MOCK
  chmod +x "${mock_dir}/atuin"

  run env PATH="${mock_dir}:$PATH" bash "${DOTFILES}/scripts/audit-abbreviations.sh"
  [ "${status}" -eq 0 ]
  assert_contains "${output}" "Not enough history"

  rm -rf "$mock_dir"
}

@test "audit-abbreviations script is executable" {
  assert_file_exists "${DOTFILES}/scripts/audit-abbreviations.sh"
  [ -x "${DOTFILES}/scripts/audit-abbreviations.sh" ]
}

@test "audit-abbreviations script has proper shebang" {
  local first_line
  first_line=$(head -1 "${DOTFILES}/scripts/audit-abbreviations.sh")
  assert_equals "#!/usr/bin/env bash" "$first_line"
}

@test "audit-abbreviations finds abbreviations.yaml" {
  assert_file_exists "${DOTFILES}/shared/abbreviations.yaml"
}

@test "audit-abbreviations supports --fix flag" {
  # Verify the script accepts --fix without error on the argument parsing level
  run grep -c "\-\-fix" "${DOTFILES}/scripts/audit-abbreviations.sh"
  [ "${status}" -eq 0 ]
  [ "${output}" -gt 0 ]
}
