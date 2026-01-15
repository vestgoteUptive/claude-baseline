#!/usr/bin/env bash
set -euo pipefail

# Replace "opencode" invocation with your OpenCode CLI command.
# Requirements:
# - Must print full assistant output to stdout.

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