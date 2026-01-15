#!/usr/bin/env bash
set -euo pipefail

# Replace "amp" invocation with your actual Amp CLI usage.
# Requirements:
# - Must print full assistant output to stdout.
# - Must return non-zero on failure (optional).

run_agent() {
  local prompt_file="$1"

  if ! command -v amp >/dev/null 2>&1; then
    echo "ERROR: amp not found on PATH"
    return 127
  fi

  # Example: feed prompt via stdin
  amp < "$prompt_file"
}