#!/bin/bash
set -euo pipefail

# detect-cli.sh - Auto-detect which AI coding assistant CLI is being used
# Outputs: claude-code, opencode, codex, or unknown
# Exit codes: 0 on success, 1 on unknown

# Scoring system:
# - Environment variables: 5 points (most reliable)
# - Directory existence: 2 points (reliable)
# - Running processes: 1 point (least reliable, many false positives)

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Auto-detect which AI coding assistant CLI is being used.

OPTIONS:
  --cli <name>    Override detection and force specific CLI
                  Valid values: claude-code, opencode, codex
  -h, --help      Show this help message

OUTPUTS:
  claude-code     Claude Code CLI detected
  opencode        OpenCode CLI detected
  codex           Codex CLI detected
  unknown         No recognized CLI detected (exit code 1)

EXAMPLES:
  ${SCRIPT_NAME}                    # Auto-detect
  ${SCRIPT_NAME} --cli opencode     # Force OpenCode
EOF
}

# Parse command-line arguments
CLI_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)
      CLI_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# If override provided, validate and output
if [[ -n "${CLI_OVERRIDE}" ]]; then
  case "${CLI_OVERRIDE}" in
    claude-code|opencode|codex)
      echo "${CLI_OVERRIDE}"
      exit 0
      ;;
    *)
      echo "Error: Invalid CLI name: ${CLI_OVERRIDE}" >&2
      echo "Valid values: claude-code, opencode, codex" >&2
      exit 1
      ;;
  esac
fi

# Initialize scores (using separate variables for bash 3.2 compatibility)
score_claude=0
score_opencode=0
score_codex=0

# Check environment variables (5 points)
if [[ -n "${CLAUDE_CODE:-}" ]]; then
  score_claude=$((score_claude + 5))
fi

if [[ -n "${OPENCODE_SESSION:-}" ]] || [[ -n "${OPENCODE_HOME:-}" ]]; then
  score_opencode=$((score_opencode + 5))
fi

if [[ -n "${CODEX_SESSION:-}" ]] || [[ -n "${CODEX_HOME:-}" ]]; then
  score_codex=$((score_codex + 5))
fi

# Check directory existence (2 points)
if [[ -d "${HOME}/.claude/projects" ]]; then
  score_claude=$((score_claude + 2))
fi

if [[ -d "${HOME}/.local/share/opencode/storage" ]]; then
  score_opencode=$((score_opencode + 2))
fi

if [[ -d "${HOME}/.codex/sessions" ]]; then
  score_codex=$((score_codex + 2))
fi

# Check running processes (1 point)
if pgrep -f "claude-code" >/dev/null 2>&1 || pgrep -f "claude_code" >/dev/null 2>&1; then
  score_claude=$((score_claude + 1))
fi

if pgrep -f "opencode" >/dev/null 2>&1; then
  score_opencode=$((score_opencode + 1))
fi

if pgrep -f "codex" >/dev/null 2>&1; then
  score_codex=$((score_codex + 1))
fi

# Find CLI with highest score (minimum 2 points required to avoid false positives)
max_score=0
detected_cli="unknown"
readonly MIN_SCORE=2

if [[ ${score_claude} -gt ${max_score} ]] && [[ ${score_claude} -ge ${MIN_SCORE} ]]; then
  max_score=${score_claude}
  detected_cli="claude-code"
fi

if [[ ${score_opencode} -gt ${max_score} ]] && [[ ${score_opencode} -ge ${MIN_SCORE} ]]; then
  max_score=${score_opencode}
  detected_cli="opencode"
fi

if [[ ${score_codex} -gt ${max_score} ]] && [[ ${score_codex} -ge ${MIN_SCORE} ]]; then
  max_score=${score_codex}
  detected_cli="codex"
fi

if [[ "${DEBUG:-}" == "1" ]]; then
  echo "Scores: claude=${score_claude} opencode=${score_opencode} codex=${score_codex}" >&2
fi

# Output result
echo "${detected_cli}"

# Exit with appropriate code
if [[ "${detected_cli}" == "unknown" ]]; then
  exit 1
else
  exit 0
fi
