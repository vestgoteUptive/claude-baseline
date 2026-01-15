#!/usr/bin/env bash
set -euo pipefail

AGENT="${AGENT:-amp}"              # amp | claude | opencode
PROMPT_FILE="${PROMPT_FILE:-prompt.md}"
MAX_ITERATIONS="${1:-0}"           # 0 = infinite (or keep upstream behavior)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="${SCRIPT_DIR}/runners/${AGENT}.sh"

if [[ ! -x "$RUNNER" ]]; then
  echo "Unknown agent runner: $RUNNER"
  echo "Set AGENT=amp|claude|opencode"
  exit 2
fi

# The only thing the runner must do:
#   run_agent "<prompt_file>"
# and it must print the agent output to stdout (so ralph can detect completion promise).
source "$RUNNER"

run_loop() {
  local i=1
  while :; do
    if [[ "$MAX_ITERATIONS" -ne 0 && "$i" -gt "$MAX_ITERATIONS" ]]; then
      echo "Reached max iterations ($MAX_ITERATIONS) without completing."
      exit 1
    fi

    run_agent "$PROMPT_FILE"

    # Your existing completion detection logic stays here (promise tag/string).
    # e.g. grep -q "<promise>COMPLETE</promise>" on captured output, etc.

    i=$((i+1))
  done
}

run_loop