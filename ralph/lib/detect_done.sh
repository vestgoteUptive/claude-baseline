#!/usr/bin/env bash
set -euo pipefail

detect_done() {
  local log_file="$1"
  local token="$2"
  grep -Fq "$token" "$log_file"
}