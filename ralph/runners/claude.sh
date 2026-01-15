#!/usr/bin/env bash
set -euo pipefail

# Replace "claude" invocation with your Claude Code CLI command.
# Common patterns:
#   - claude < prompt.md
#   - claude --print < prompt.md
#   - claude chat --stdin < prompt.md
#
# Requirements:
# - Must print full assistant output to stdout.

run_agent() {
  local prompt_file="$1"

  if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: claude not found on PATH"
    echo "Install/enable Claude Code CLI and ensure 'claude' works."
    return 127
  fi

  # Placeholder: adjust flags to whatever your Claude Code supports
  claude < "$prompt_file"
}