#!/usr/bin/env bash
set -euo pipefail

# Claude Code runner for Ralph
#
# Uses --print flag for non-interactive output
# Uses --dangerously-skip-permissions for autonomous operation
#
# Requirements:
# - Must print full assistant output to stdout
# - Claude CLI must be installed and available on PATH

run_agent() {
  local prompt_file="$1"

  if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: claude not found on PATH"
    echo "Install/enable Claude Code CLI and ensure 'claude' works."
    return 127
  fi

  # Use --print for non-interactive output
  # --dangerously-skip-permissions: bypass permission checks (for autonomous mode)
  # Reading prompt from stdin with < operator
  claude --print --dangerously-skip-permissions < "$prompt_file"
}