#!/usr/bin/env bash
#
# Abbreviation auditor
# Cross-references shell history (via Atuin) against shared/abbreviations.yaml
# to find unused abbreviations and frequently-typed commands that could be abbreviated.
#
# Usage:
#   audit-abbreviations.sh          # Report only
#   audit-abbreviations.sh --fix    # Remove unused abbreviations and regenerate
#
# Requires: atuin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "${SCRIPT_DIR}")"
ABBR_FILE="${DOTFILES_DIR}/shared/abbreviations.yaml"
MIN_HISTORY=100
PROMOTE_THRESHOLD=10 # minimum uses to suggest promotion
FIX_MODE=false

if [[ "${1:-}" == "--fix" ]]; then
  FIX_MODE=true
fi

# --- Guards ---

if ! command -v atuin >/dev/null 2>&1; then
  echo "Error: atuin not installed." >&2
  echo "Install: brew install atuin" >&2
  exit 1
fi

if [[ ! -f "${ABBR_FILE}" ]]; then
  echo "Error: Abbreviation file not found: ${ABBR_FILE}" >&2
  exit 1
fi

# --- Dump history once to temp file ---

HISTORY_FILE=$(mktemp)
trap 'rm -f "${HISTORY_FILE}"' EXIT
atuin history list --format "{command}" 2>/dev/null > "${HISTORY_FILE}"

history_count=$(wc -l < "${HISTORY_FILE}" | tr -d ' ')

if [[ "${history_count}" -lt "${MIN_HISTORY}" ]]; then
  echo "Not enough history yet (${history_count} commands)."
  echo "Run again after 2+ weeks of usage for meaningful results."
  exit 0
fi

echo "Analyzing ${history_count} commands from Atuin history..."
echo ""

# --- Build frequency map (single pass) ---

declare -A cmd_freq

while IFS= read -r cmd; do
  # Extract the first word (the command itself)
  first_word="${cmd%% *}"
  if [[ -n "${first_word}" ]]; then
    cmd_freq["${first_word}"]=$((${cmd_freq["${first_word}"]:-0} + 1))
  fi
done < "${HISTORY_FILE}"

# --- Extract abbreviations from YAML ---
# Parse abbreviation keys and their commands from the YAML file
# Format: category -> abbr_name -> command: "the command"

declare -A abbr_map # abbr_name -> command

while IFS= read -r line; do
  # Match lines like '  abbr_name:' (2-space indent, abbreviation key)
  if [[ "${line}" =~ ^[[:space:]]{2}([a-zA-Z0-9_-]+):$ ]]; then
    current_abbr="${BASH_REMATCH[1]}"
  fi
  # Match lines like '    command: "the command"'
  if [[ "${line}" =~ ^[[:space:]]{4}command:[[:space:]]*\"(.+)\" ]]; then
    if [[ -n "${current_abbr:-}" ]]; then
      abbr_map["${current_abbr}"]="${BASH_REMATCH[1]}"
      current_abbr=""
    fi
  fi
done <"${ABBR_FILE}"

# --- Find unused abbreviations ---

unused=()
used_count=0
total_abbrs=${#abbr_map[@]}

for abbr in "${!abbr_map[@]}"; do
  expanded="${abbr_map[${abbr}]}"
  # Extract the base command from the expansion
  base_cmd="${expanded%% *}"

  # Check if either the abbreviation or its base command appears in history
  abbr_uses=${cmd_freq["${abbr}"]:-0}
  cmd_uses=${cmd_freq["${base_cmd}"]:-0}

  if [[ ${abbr_uses} -eq 0 && ${cmd_uses} -eq 0 ]]; then
    unused+=("${abbr} -> ${expanded}")
  else
    used_count=$((used_count + 1))
  fi
done

# --- Find promotable commands ---

promotable=()

for cmd in "${!cmd_freq[@]}"; do
  count=${cmd_freq["${cmd}"]}
  if [[ ${count} -ge ${PROMOTE_THRESHOLD} ]]; then
    # Check if this command already has an abbreviation
    has_abbr=false
    for abbr in "${!abbr_map[@]}"; do
      expanded="${abbr_map[${abbr}]}"
      base_cmd="${expanded%% *}"
      if [[ "${base_cmd}" == "${cmd}" || "${abbr}" == "${cmd}" ]]; then
        has_abbr=true
        break
      fi
    done

    if [[ "${has_abbr}" == "false" ]]; then
      promotable+=("${cmd} (used ${count} times)")
    fi
  fi
done

# --- Report ---

echo "=== Abbreviation Audit Report ==="
echo ""
echo "Total abbreviations: ${total_abbrs}"
echo "Used (found in history): ${used_count}"
echo "Unused (no history match): ${#unused[@]}"
echo "Promotable commands: ${#promotable[@]}"
echo ""

if [[ ${#unused[@]} -gt 0 ]]; then
  echo "--- Unused Abbreviations (candidates for removal) ---"
  printf '%s\n' "${unused[@]}" | sort
  echo ""
fi

if [[ ${#promotable[@]} -gt 0 ]]; then
  echo "--- Promotable Commands (consider adding abbreviations) ---"
  printf '%s\n' "${promotable[@]}" | sort -t'(' -k2 -rn
  echo ""
fi

if [[ ${#unused[@]} -eq 0 && ${#promotable[@]} -eq 0 ]]; then
  echo "All abbreviations are in use. No changes needed."
fi

# --- Fix mode ---

if [[ "${FIX_MODE}" == "true" && ${#unused[@]} -gt 0 ]]; then
  echo ""
  echo "--- Fix Mode ---"

  # Create backup
  cp "${ABBR_FILE}" "${ABBR_FILE}.bak"
  echo "Backup created: ${ABBR_FILE}.bak"

  # Remove unused abbreviations from YAML
  removed=0
  for entry in "${unused[@]}"; do
    abbr_name="${entry%% ->*}"
    # Remove the abbreviation block (key + command + description lines)
    # Use sed to remove the block
    if grep -q "^  ${abbr_name}:$" "${ABBR_FILE}"; then
      # Remove the abbreviation key and its indented children (command, description)
      sed -i.tmp "/^  ${abbr_name}:$/,/^  [^ ]/{ /^  ${abbr_name}:$/d; /^    /d; }" "${ABBR_FILE}"
      rm -f "${ABBR_FILE}.tmp"
      removed=$((removed + 1))
    fi
  done

  echo "Removed ${removed} unused abbreviations from ${ABBR_FILE}"

  # Regenerate shell-specific files
  echo "Regenerating abbreviation files..."
  cd "${DOTFILES_DIR}/shared"
  bash generate-fish-abbr.sh
  bash generate-zsh-abbr.sh
  echo "Done. Review changes with: git diff shared/"
fi
