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
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# IMPORTANT: Don't cd to SCRIPT_DIR - stay in project root!
# This allows Ralph to work as a git submodule while accessing project files.

AGENT="${AGENT:-amp}"                       # amp | claude | opencode
STATE_DIR="${STATE_DIR:-.ralph}"            # persistent state folder (in project root)
MAX_ITERATIONS=0                            # 0 = infinite
COMPLETION_TOKEN="${COMPLETION_TOKEN:-<RALPH_DONE/>}"

# Prompt file: Try project root first, fallback to Ralph's default
if [[ -n "${PROMPT_FILE:-}" ]]; then
  # User specified a prompt file, use as-is
  :
elif [[ -f "${PROJECT_ROOT}/prompt.md" ]]; then
  PROMPT_FILE="${PROJECT_ROOT}/prompt.md"
elif [[ -f "${PROJECT_ROOT}/ralph-prompt.md" ]]; then
  PROMPT_FILE="${PROJECT_ROOT}/ralph-prompt.md"
else
  # Fallback to Ralph's default prompt
  PROMPT_FILE="${SCRIPT_DIR}/prompt.md"
fi

usage() {
  cat <<EOF
Usage: ./ralph.sh [options]

Options:
  --agent <amp|claude|opencode>     Choose agent runner (or set AGENT env var)
  --prompt <file>                   Base prompt file (default: auto-detect)
  --work-dir <dir>                  Project root directory (default: current directory)
  --state-dir <dir>                 State directory (default: .ralph in project root)
  --max-iterations <n>              Stop after n iterations (default: 0 = infinite)
  --completion-token <token>        Token that marks completion (default: <RALPH_DONE/>)
  -h, --help                        Show help

Prompt file detection (in order):
  1. --prompt <file> (if specified)
  2. PROJECT_ROOT/prompt.md
  3. PROJECT_ROOT/ralph-prompt.md
  4. RALPH_DIR/prompt.md (fallback)

Environment variables:
  AGENT              Agent to use (amp|claude|opencode)
  PROJECT_ROOT       Project root directory
  PROMPT_FILE        Prompt file path
  STATE_DIR          State directory path

Examples:
  # Run from project root (Ralph as submodule)
  ./ralph/ralph.sh --agent claude

  # Run from anywhere with explicit work directory
  /path/to/ralph/ralph.sh --work-dir /path/to/project --agent opencode

  # Use custom prompt
  ./ralph/ralph.sh --prompt my-custom-prompt.md --max-iterations 5
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2;;
    --prompt) PROMPT_FILE="$2"; shift 2;;
    --work-dir) PROJECT_ROOT="$2"; shift 2;;
    --state-dir) STATE_DIR="$2"; shift 2;;
    --max-iterations) MAX_ITERATIONS="$2"; shift 2;;
    --completion-token) COMPLETION_TOKEN="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1"; usage; exit 2;;
  esac
done

# After parsing args, re-detect prompt if not explicitly set
if [[ -z "${PROMPT_FILE:-}" ]]; then
  if [[ -f "${PROJECT_ROOT}/prompt.md" ]]; then
    PROMPT_FILE="${PROJECT_ROOT}/prompt.md"
  elif [[ -f "${PROJECT_ROOT}/ralph-prompt.md" ]]; then
    PROMPT_FILE="${PROJECT_ROOT}/ralph-prompt.md"
  else
    PROMPT_FILE="${SCRIPT_DIR}/prompt.md"
  fi
fi

# Change to project root if specified differently
if [[ "$(pwd)" != "$PROJECT_ROOT" ]]; then
  cd "$PROJECT_ROOT"
fi

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
echo "  Project root:     $PROJECT_ROOT"
echo "  Ralph dir:        $SCRIPT_DIR"
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
    --ralph-dir "$SCRIPT_DIR" \
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