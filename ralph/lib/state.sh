#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1"
    exit 2
  }
}

init_state() {
  local state_dir="$1"
  mkdir -p "$state_dir/runs"
  if [[ ! -f "$state_dir/context.md" ]]; then
    cat > "$state_dir/context.md" <<EOF
# Repo context (optional)

Add anything here that should be included in every iteration.
Examples:
- target branch / constraints
- high-level goal
- links to PRD / issue
EOF
  fi
}

step_begin() {
  local state_dir="$1"
  local iter="$2"

  echo "$iter" > "${state_dir}/iteration.txt"
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "${state_dir}/last_start_utc.txt"
}

step_end() {
  local state_dir="$1"
  local iter="$2"
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "${state_dir}/last_end_utc.txt"
  echo "ok" > "${state_dir}/runs/${iter}.status"
}