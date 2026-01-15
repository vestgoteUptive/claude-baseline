#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Ralph orchestrator (agent-agnostic loop)
#
# Usage examples:
#   AGENT=claude ./ralph.sh
#   AGENT=opencode ./ralph.sh --max-iterations 10
#   ./ralph.sh --agent amp --max-iterations 3 --prompt prompt.md
#
# Contract:
# - We build an effective prompt each iteration by inlining skills + context.
# - We call a runner that prints agent output to stdout.
# - We stop when output contains the completion token: <RALPH_DONE/>
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

AGENT="${AGENT:-amp}"                       # amp | claude | opencode
PROMPT_FILE="${PROMPT_FILE:-prompt.md}"     # base prompt
STATE_DIR="${STATE_DIR:-.ralph}"            # persistent state folder
MAX_ITERATIONS=0                            # 0 = infinite
COMPLETION_TOKEN="${COMPLETION_TOKEN:-<RALPH_DONE/>}"

usage() {
  cat <<EOF
Usage: ./ralph.sh [options]

Options:
  --agent <amp|claude|opencode>     Choose agent runner (or set AGENT env var)
  --prompt <file>                  Base prompt file (default: prompt.md)
  --state-dir <dir>                State directory (default: .ralph)
  --max-iterations <n>             Stop after n iterations (default: 0 = infinite)
  --completion-token <token>       Token that marks completion (default: <RALPH_DONE/>)
  -h, --help                       Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2;;
    --prompt) PROMPT_FILE="$2"; shift 2;;
    --state-dir) STATE_DIR="$2"; shift 2;;
    --max-iterations) MAX_ITERATIONS="$2"; shift 2;;
    --completion-token) COMPLETION_TOKEN="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1"; usage; exit 2;;
  esac
done

RUNNER="${SCRIPT_DIR}/runners/${AGENT}.sh"
if [[ ! -f "$RUNNER" ]]; then
  echo "ERROR: Unknown agent runner: $RUNNER"
  echo "Expected one of: amp | claude | opencode"
  exit 2
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/prompt_builder.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/state.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/detect_done.sh"
# shellcheck source=/dev/null
source "$RUNNER"

require_cmd git

mkdir -p "$STATE_DIR"
init_state "$STATE_DIR"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: Base prompt not found: $PROMPT_FILE"
  exit 2
fi

echo "Ralph starting"
echo "  Agent:            $AGENT"
echo "  Base prompt:      $PROMPT_FILE"
echo "  State dir:        $STATE_DIR"
echo "  Max iterations:   $MAX_ITERATIONS"
echo "  Completion token: $COMPLETION_TOKEN"
echo

ITER=1
while :; do
  if [[ "$MAX_ITERATIONS" -ne 0 && "$ITER" -gt "$MAX_ITERATIONS" ]]; then
    echo "ERROR: reached max iterations ($MAX_ITERATIONS) without completing."
    exit 1
  fi

  step_begin "$STATE_DIR" "$ITER"

  EFFECTIVE_PROMPT="${STATE_DIR}/effective_prompt.md"
  build_effective_prompt \
    --agent "$AGENT" \
    --base "$PROMPT_FILE" \
    --state-dir "$STATE_DIR" \
    --out "$EFFECTIVE_PROMPT"

  OUTPUT_LOG="${STATE_DIR}/runs/${ITER}.log"
  mkdir -p "$(dirname "$OUTPUT_LOG")"

  echo "== Iteration $ITER =="
  echo "Running agent runner: $AGENT"
  echo

  # Runner prints to stdout; we tee into log
  set +e
  run_agent "$EFFECTIVE_PROMPT" 2>&1 | tee "$OUTPUT_LOG"
  RUN_EXIT="${PIPESTATUS[0]}"
  set -e

  if [[ "$RUN_EXIT" -ne 0 ]]; then
    echo
    echo "WARN: runner exited with code $RUN_EXIT"
    echo "Continuing loop unless completion token is found."
    echo
  fi

  if detect_done "$OUTPUT_LOG" "$COMPLETION_TOKEN"; then
    echo
    echo "✅ Completion token detected: $COMPLETION_TOKEN"
    echo "Ralph finished in $ITER iteration(s)."
    exit 0
  fi

  step_end "$STATE_DIR" "$ITER"
  ITER=$((ITER + 1))
done