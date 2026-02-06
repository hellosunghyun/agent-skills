#!/usr/bin/env bash
set -euo pipefail

# generate-report.sh - Generate HTML report from insights and stats JSON
#
# Usage: generate-report.sh [OPTIONS]
#
# OPTIONS:
#   --stats <path>        Path to stats JSON file (required)
#   --cli <type>          CLI type (claude-code, opencode, codex)
#   --output <path>       Output HTML file path (default: ./insights-report.html)
#   -h, --help            Show help
#
# STDIN: Insights JSON (from analysis prompts)
# STDOUT: Path to generated HTML file
#
# EXAMPLE:
#   echo "$INSIGHTS_JSON" | ./generate-report.sh --stats stats.json --cli claude-code --output report.html

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATE_PATH="${SCRIPT_DIR}/templates/report.html"

usage() {
  cat <<EOF
Usage: generate-report.sh [OPTIONS]

Generate HTML report from insights and stats JSON data.

OPTIONS:
  --stats <path>        Path to stats JSON file (required)
  --cli <type>          CLI type (claude-code, opencode, codex) (default: unknown)
  --output <path>       Output HTML file path (default: ./insights-report.html)
  -h, --help            Show this help message

STDIN: Insights JSON (from analysis prompts)
STDOUT: Path to generated HTML file

EXAMPLE:
  echo "\$INSIGHTS_JSON" | ./generate-report.sh --stats stats.json --cli claude-code --output report.html
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

main() {
  local stats_file=""
  local cli_type="unknown"
  local output_file="./insights-report.html"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stats)
        stats_file="$2"
        shift 2
        ;;
      --cli)
        cli_type="$2"
        shift 2
        ;;
      --output)
        output_file="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  [[ -n "$stats_file" ]] || die "Missing required argument: --stats <path>"
  [[ -f "$stats_file" ]] || die "Stats file not found: $stats_file"
  [[ -f "$TEMPLATE_PATH" ]] || die "Template not found: $TEMPLATE_PATH"

  local insights_json
  insights_json=$(cat)
  [[ -n "$insights_json" ]] || die "No insights JSON provided on stdin"

  local stats_json
  stats_json=$(cat "$stats_file")
  [[ -n "$stats_json" ]] || die "Stats file is empty: $stats_file"

  local generated_date
  generated_date=$(date -u +"%Y-%m-%d")

  python3 -c "
import sys
import re

template = open('$TEMPLATE_PATH', 'r').read()
stats = '''$stats_json'''
insights = '''$insights_json'''
date = '$generated_date'
cli = '$cli_type'

output = template.replace('{{STATS_JSON}}', stats)
output = output.replace('{{INSIGHTS_JSON}}', insights)
output = output.replace('{{GENERATED_DATE}}', date)
output = output.replace('{{CLI_TYPE}}', cli)

with open('$output_file', 'w') as f:
    f.write(output)
"

  echo "$output_file"
}

main "$@"
