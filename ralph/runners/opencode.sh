#!/usr/bin/env bash
set -euo pipefail

# OpenCode runner for Ralph
#
# NOTE: Update this with actual OpenCode CLI flags once tested
# Common patterns to try:
#   - opencode --non-interactive < prompt.md
#   - opencode exec < prompt.md
#   - opencode run --stdin < prompt.md
#
# Requirements:
# - Must print full assistant output to stdout
# - OpenCode CLI must be installed and available on PATH

run_agent() {
  local prompt_file="$1"

  if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: opencode not found on PATH"
    echo "Install/enable OpenCode CLI and ensure 'opencode' works."
    return 127
  fi

  # Placeholder: adjust flags to whatever your OpenCode supports
  opencode < "$prompt_file"
}