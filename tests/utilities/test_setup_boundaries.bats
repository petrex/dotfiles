#!/usr/bin/env bats
# shellcheck disable=SC2317
bats_require_minimum_version 1.5.0

load '../helpers/common.bash'
load '../helpers/shell_helpers.bash'

setup() {
  setup_dotfiles_path
  TEST_HOME="${BATS_TEST_TMPDIR}/home"
  MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
  CALL_LOG="${BATS_TEST_TMPDIR}/calls.log"
  mkdir -p "${TEST_HOME}" "${MOCK_BIN}"
  : >"${CALL_LOG}"

  printf '#!/usr/bin/env bash\nprintf "stow %%s\\n" "$*" >>"%s"\n' \
    "${CALL_LOG}" >"${MOCK_BIN}/stow"
  printf '#!/usr/bin/env bash\nprintf "sudo %%s\\n" "$*" >>"%s"\nexit 99\n' \
    "${CALL_LOG}" >"${MOCK_BIN}/sudo"
  printf '#!/usr/bin/env bash\nprintf "git %%s\\n" "$*" >>"%s"\nexit 99\n' \
    "${CALL_LOG}" >"${MOCK_BIN}/git"
  chmod +x "${MOCK_BIN}/stow" "${MOCK_BIN}/sudo" "${MOCK_BIN}/git"
}

@test "link setup completes without sudo or network access" {
	run env -u XDG_CONFIG_HOME \
    HOME="${TEST_HOME}" \
    DOTFILES="${DOTFILES}" \
    PATH="${MOCK_BIN}:${PATH}" \
    bash "${DOTFILES}/setup.sh"

  [ "${status}" -eq 0 ]
  [ -d "${TEST_HOME}/.config" ]
  [ -d "${TEST_HOME}/.local/bin" ]
  grep -q '^stow ' "${CALL_LOG}"
  run grep -Eq '^(sudo|git) ' "${CALL_LOG}"
  [ "${status}" -eq 1 ]
}

@test "link setup contains no privileged or user-state commands" {
  run grep -En '^[[:space:]]*(sudo|scutil|defaults|fish|tic|git)[[:space:]]' \
    "${DOTFILES}/setup.sh"

  [ "${status}" -eq 1 ]
}

@test "user setup never invokes sudo" {
  run grep -En '^[[:space:]]*sudo([[:space:]]|$)' \
    "${DOTFILES}/scripts/setup-user.sh"

  [ "${status}" -eq 1 ]
}

@test "system setup dry-run does not invoke sudo" {
  printf '#!/usr/bin/env bash\nprintf "Darwin\\n"\n' >"${MOCK_BIN}/uname"
  printf '#!/usr/bin/env bash\ncase "$*" in\n  *ComputerName*) printf "Test Mac\\n" ;;\n  *LocalHostName*) printf "test-mac\\n" ;;\nesac\n' \
    >"${MOCK_BIN}/scutil"
  chmod +x "${MOCK_BIN}/uname" "${MOCK_BIN}/scutil"

  run env PATH="${MOCK_BIN}:${PATH}" \
    bash "${DOTFILES}/scripts/setup-system.sh" --dry-run

  [ "${status}" -eq 0 ]
  assert_contains "${output}" "No administrator access requested"
  run grep -q '^sudo ' "${CALL_LOG}"
  [ "${status}" -eq 1 ]
}
