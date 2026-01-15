#!/usr/bin/env bash
set -euo pipefail

# Builds an effective prompt by concatenating:
#   1) base prompt
#   2) state/context (optional)
#   3) common skills
#   4) agent-specific skills
#
# This is the portable way to "reuse skills" across Amp/Claude/OpenCode:
# everyone gets the same instruction content, inlined into the prompt.

build_effective_prompt() {
  local agent=""
  local base=""
  local state_dir=""
  local out=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2;;
      --base) base="$2"; shift 2;;
      --state-dir) state_dir="$2"; shift 2;;
      --out) out="$2"; shift 2;;
      *) echo "prompt_builder: unknown arg $1"; exit 2;;
    esac
  done

  if [[ -z "$agent" || -z "$base" || -z "$state_dir" || -z "$out" ]]; then
    echo "prompt_builder: missing required args"
    exit 2
  fi

  : > "$out"

  cat "$base" >> "$out"
  echo -e "\n\n---\n" >> "$out"

  # State/context block (optional files you can grow over time)
  if [[ -f "${state_dir}/context.md" ]]; then
    echo "# Context" >> "$out"
    cat "${state_dir}/context.md" >> "$out"
    echo -e "\n\n---\n" >> "$out"
  fi

  # Skills
  echo "# Loaded skills" >> "$out"
  echo >> "$out"

  if [[ -d "skills/common" ]]; then
    for f in skills/common/*.md; do
      [[ -f "$f" ]] || continue
      echo "## $(basename "$f")" >> "$out"
      echo >> "$out"
      cat "$f" >> "$out"
      echo -e "\n" >> "$out"
    done
  fi

  if [[ -d "skills/${agent}" ]]; then
    for f in "skills/${agent}"/*.md; do
      [[ -f "$f" ]] || continue
      echo "## $(basename "$f")" >> "$out"
      echo >> "$out"
      cat "$f" >> "$out"
      echo -e "\n" >> "$out"
    done
  fi

  echo -e "\n---\n" >> "$out"
  echo "When you are fully done, print this exact token on its own line:" >> "$out"
  echo "$COMPLETION_TOKEN" >> "$out"
}