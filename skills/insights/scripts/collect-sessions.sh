#!/usr/bin/env bash
set -euo pipefail

# collect-sessions.sh - Collect session metadata from AI coding assistant CLIs
# Outputs: JSON array of session metadata objects to stdout
# Supports: claude-code, opencode, codex
# Usage: ./collect-sessions.sh --cli <type> [--session-dir <path>] [--limit N]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# --- Helpers ---

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Collect session metadata from AI coding assistant CLIs.
Outputs a JSON array of session objects sorted by start_time descending.

OPTIONS:
  --cli <type>          CLI type: claude-code, opencode, codex
                         (auto-detects if not specified)
  --session-dir <path>  Override default session directory
  --limit <N>           Maximum sessions to return (default: unlimited)
  --days <N>            Only include sessions from the last N days (default: 30)
  -h, --help            Show this help message

EXAMPLES:
  ${SCRIPT_NAME} --cli claude-code
  ${SCRIPT_NAME} --cli opencode --limit 10
  ${SCRIPT_NAME} --cli codex --session-dir ~/.codex/sessions
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed. Run: brew install jq"
}

calculate_cutoff_date() {
  local days="${1:-30}"
  local cutoff=""

  if date -v -1d +"%Y-%m-%dT%H:%M:%SZ" &>/dev/null 2>&1; then
    cutoff=$(date -u -v -${days}d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)
  fi

  if [[ -z "$cutoff" ]]; then
    if date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%SZ" &>/dev/null 2>&1; then
      cutoff=$(date -u -d "${days} days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || true)
    fi
  fi

  if [[ -z "$cutoff" ]]; then
    cutoff=$(python3 - <<PY
from datetime import datetime, timedelta, timezone
days = int("${days}")
cutoff = datetime.now(timezone.utc) - timedelta(days=days)
print(cutoff.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)
  fi

  echo "$cutoff"
}

# Convert ISO-8601 timestamp to epoch seconds (portable)
iso_to_epoch() {
  local ts="$1"
  # Try GNU date first, then BSD date
  if date -d "$ts" +%s 2>/dev/null; then
    return
  fi
  # BSD date (macOS) — handle ISO format
  local cleaned
  cleaned=$(echo "$ts" | sed 's/\.[0-9]*Z$/Z/' | sed 's/Z$/+0000/' | sed 's/T/ /')
  date -j -f "%Y-%m-%d %H:%M:%S%z" "$cleaned" +%s 2>/dev/null || echo "0"
}

# Convert epoch milliseconds to ISO-8601
epoch_ms_to_iso() {
  local ms="$1"
  local secs=$((ms / 1000))
  # Try GNU date first, then BSD date
  if date -u -d "@${secs}" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null; then
    return
  fi
  # BSD date (macOS)
  date -u -r "${secs}" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || echo "1970-01-01T00:00:00.000Z"
}

# --- Claude Code Adapter ---

collect_claude_code() {
  local session_dir="${1:-${HOME}/.claude/projects}"
  local limit="${2:-0}"
  local days="${3:-30}"
  local sessions_json="[]"
  local cutoff_date
  cutoff_date=$(calculate_cutoff_date "$days")

  # Find all .jsonl session files, excluding agent-* directories
  local files=()
  while IFS= read -r -d '' f; do
    # Skip files in agent-* directories
    local relpath="${f#"${session_dir}"/}"
    local first_component="${relpath%%/*}"
    if [[ "$first_component" == agent-* ]]; then
      continue
    fi
    files+=("$f")
  done < <(find "$session_dir" -name '*.jsonl' -type f -print0 2>/dev/null || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "[]"
    return 0
  fi

  for file in "${files[@]}"; do
    # Parse JSONL: extract user/assistant messages only, skip malformed lines
    local parsed
    parsed=$(jq -s '
      [.[] | select(.type == "user" or .type == "assistant")]
    ' "$file" 2>/dev/null) || continue

    # Count messages
    local total user_count assistant_count
    total=$(echo "$parsed" | jq 'length') || continue
    user_count=$(echo "$parsed" | jq '[.[] | select(.type == "user")] | length') || continue
    assistant_count=$(echo "$parsed" | jq '[.[] | select(.type == "assistant")] | length') || continue

    # Filter: skip sessions with <2 messages
    if [[ "$total" -lt 2 ]]; then
      continue
    fi

    # Extract timestamps
    local start_time end_time
    start_time=$(echo "$parsed" | jq -r 'first.timestamp // empty') || continue
    end_time=$(echo "$parsed" | jq -r 'last.timestamp // empty') || continue

    if [[ -z "$start_time" || -z "$end_time" ]]; then
      continue
    fi

    # Calculate duration in minutes
    local start_epoch end_epoch duration_secs duration_minutes
    start_epoch=$(iso_to_epoch "$start_time")
    end_epoch=$(iso_to_epoch "$end_time")
    duration_secs=$(( end_epoch - start_epoch ))
    duration_minutes=$(( duration_secs / 60 ))

    # Filter: skip sessions with <1 minute duration
    if [[ "$duration_secs" -lt 60 ]]; then
      continue
    fi

    # Extract metadata from first message
    local session_id cwd git_branch model
    session_id=$(echo "$parsed" | jq -r 'first.sessionId // "unknown"')
    cwd=$(echo "$parsed" | jq -r 'first.cwd // null')
    git_branch=$(echo "$parsed" | jq -r 'first.gitBranch // null')

    # Extract tools used from assistant messages (tool_use blocks in content)
    local tools_used
    tools_used=$(echo "$parsed" | jq -c '
      [.[] | select(.type == "assistant") | .message.content |
       if type == "array" then
         [.[] | select(.type == "tool_use") | .name] | .[]
       else empty end
      ] | unique
    ' 2>/dev/null) || tools_used="[]"

    # Extract model (not always present in Claude Code JSONL, use null)
    model=$(echo "$parsed" | jq -r '
      [.[] | .model // empty] | first // null
    ' 2>/dev/null) || model="null"

    # Build session JSON object
    local session_obj
    session_obj=$(jq -n \
      --arg sid "$session_id" \
      --arg st "$start_time" \
      --arg et "$end_time" \
      --argjson dm "$duration_minutes" \
      --argjson uc "$user_count" \
      --argjson ac "$assistant_count" \
      --argjson tm "$total" \
      --argjson tu "$tools_used" \
      --arg pp "$cwd" \
      --arg gb "$git_branch" \
      --argjson it 0 \
      --argjson ot 0 \
      --arg md "$model" \
      '{
        session_id: $sid,
        start_time: $st,
        end_time: $et,
        duration_minutes: $dm,
        user_message_count: $uc,
        assistant_message_count: $ac,
        total_messages: $tm,
        tools_used: $tu,
        project_path: (if $pp == "null" then null else $pp end),
        git_branch: (if $gb == "null" then null else $gb end),
        input_tokens: $it,
        output_tokens: $ot,
        model: (if $md == "null" then null else $md end)
      }')

    sessions_json=$(echo "$sessions_json" | jq --argjson obj "$session_obj" '. + [$obj]')
  done

  # Sort by start_time descending and apply limit
  echo "$sessions_json" | jq --argjson limit "$limit" --arg cutoff "$cutoff_date" '
    [.[] | select(.start_time >= $cutoff)] | sort_by(.start_time) | reverse | if $limit > 0 then .[:$limit] else . end
  '
}

# --- OpenCode Adapter ---

collect_opencode() {
  local session_dir="${1:-${HOME}/.local/share/opencode/storage}"
  local limit="${2:-0}"
  local days="${3:-30}"
  local session_base="${session_dir}/session"
  local message_base="${session_dir}/message"
  local cutoff_date
  cutoff_date=$(calculate_cutoff_date "$days")

  local process_limit
  if [[ "$limit" -gt 0 ]]; then
    process_limit=$((limit * 3))
  else
    process_limit=9999
  fi
  local session_files=()
  # Cross-platform stat: try BSD (macOS) first, then GNU (Linux)
  local stat_output
  if stat -f '%m %N' /dev/null &>/dev/null 2>&1; then
    stat_output=$(find "$session_base" -name '*.json' -type f -exec stat -f '%m %N' {} + 2>/dev/null)
  else
    stat_output=$(find "$session_base" -name '*.json' -type f -exec stat -c '%Y %n' {} + 2>/dev/null)
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] && session_files+=("$f")
  done < <(echo "$stat_output" | sort -rn | head -n "$process_limit" | sed 's/^[^ ]* //')

  if [[ ${#session_files[@]} -eq 0 ]]; then
    echo "[]"
    return 0
  fi

  local tmpfile
  tmpfile=$(mktemp)
  local first=true
  local collected=0

  echo "[" > "$tmpfile"

  for session_file in "${session_files[@]}"; do
    local meta
    meta=$(jq -r '[.id // "", .directory // ""] | @tsv' "$session_file" 2>/dev/null) || continue
    local session_id="${meta%%	*}"
    local directory="${meta#*	}"

    [[ -z "$session_id" ]] && continue

    local msg_dir="${message_base}/${session_id}"
    [[ ! -d "$msg_dir" ]] && continue

    # Batch all message files into a single jq -s call (avoids N×6 jq spawns per session)
    local session_obj
    session_obj=$(find "$msg_dir" -name '*.json' -type f -exec cat {} + 2>/dev/null | \
      jq -s --arg sid "$session_id" --arg dir "$directory" '
        if length < 2 then empty
        else
          ([.[] | select(.role == "user")] | length) as $uc |
          ([.[] | select(.role == "assistant")] | length) as $ac |
          ([.[] | .timestamp // .time.created // 0] | min) as $min_ts |
          ([.[] | .timestamp // .time.created // 0] | max) as $max_ts |
          (($max_ts - $min_ts) / 1000) as $dur_secs |
          if $dur_secs < 60 then empty
          else
            {
              session_id: $sid,
              start_time: (($min_ts / 1000 | floor) | todate),
              end_time: (($max_ts / 1000 | floor) | todate),
              duration_minutes: (($dur_secs / 60) | floor),
              user_message_count: $uc,
              assistant_message_count: $ac,
              total_messages: ($uc + $ac),
              tools_used: [],
              project_path: (if $dir == "" then null else $dir end),
              git_branch: null,
              input_tokens: ([.[] | .tokens.input // 0] | add // 0),
              output_tokens: ([.[] | .tokens.output // 0] | add // 0),
              model: ([.[] | (.model | if type == "object" then .modelID else . end) // empty] | last // null)
            }
          end
        end
      ' 2>/dev/null) || continue

    [[ -z "$session_obj" || "$session_obj" == "null" ]] && continue

    if [[ "$first" == true ]]; then
      first=false
    else
      echo "," >> "$tmpfile"
    fi
    echo "$session_obj" >> "$tmpfile"

    collected=$((collected + 1))
    [[ "$limit" -gt 0 && "$collected" -ge "$limit" ]] && break
  done

  echo "]" >> "$tmpfile"

  jq --argjson limit "$limit" --arg cutoff "$cutoff_date" '
    [.[] | select(.start_time >= $cutoff)] | sort_by(.start_time) | reverse | if $limit > 0 then .[:$limit] else . end
  ' "$tmpfile"
  rm -f "$tmpfile"
}

# --- Codex Adapter ---

collect_codex() {
  local session_dir="${1:-${HOME}/.codex/sessions}"
  local limit="${2:-0}"
  local days="${3:-30}"
  local sessions_json="[]"
  local cutoff_date
  cutoff_date=$(calculate_cutoff_date "$days")

  # Find all .jsonl rollout files
  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$session_dir" -name '*.jsonl' -type f -print0 2>/dev/null || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "[]"
    return 0
  fi

  for file in "${files[@]}"; do
    local parsed
    parsed=$(jq -s '.' "$file" 2>/dev/null) || continue

    local line_count
    line_count=$(echo "$parsed" | jq 'length')

    if [[ "$line_count" -lt 1 ]]; then
      continue
    fi

    # Extract session_meta
    local meta
    meta=$(echo "$parsed" | jq 'map(select(.type == "session_meta")) | first // empty')

    if [[ -z "$meta" || "$meta" == "null" ]]; then
      continue
    fi

    local session_id project_path git_branch model_name
    session_id=$(echo "$meta" | jq -r '.payload.session_id // empty')
    project_path=$(echo "$meta" | jq -r '.payload.project_path // null')
    git_branch=$(echo "$meta" | jq -r '.payload.git_branch // null')
    model_name=$(echo "$meta" | jq -r '.payload.model // null')

    if [[ -z "$session_id" ]]; then
      continue
    fi

    # Extract response items
    local responses
    responses=$(echo "$parsed" | jq '[.[] | select(.type == "response_item")]')
    local response_count
    response_count=$(echo "$responses" | jq 'length')

    # Count total messages across all response_items
    local user_count assistant_count total_messages
    user_count=$(echo "$responses" | jq '
      [.[] | .payload.messages // [] | .[] | select(.role == "user")] | length
    ')
    assistant_count=$(echo "$responses" | jq '
      [.[] | .payload.messages // [] | .[] | select(.role == "assistant")] | length
    ')
    total_messages=$((user_count + assistant_count))

    # Filter: skip sessions with <2 total messages
    if [[ "$total_messages" -lt 2 ]]; then
      continue
    fi

    # Get timestamps (first and last entries)
    local start_time end_time
    start_time=$(echo "$parsed" | jq -r 'first.timestamp // empty')
    end_time=$(echo "$parsed" | jq -r 'last.timestamp // empty')

    if [[ -z "$start_time" || -z "$end_time" ]]; then
      continue
    fi

    # Calculate duration
    local start_epoch end_epoch duration_secs duration_minutes
    start_epoch=$(iso_to_epoch "$start_time")
    end_epoch=$(iso_to_epoch "$end_time")
    duration_secs=$((end_epoch - start_epoch))
    duration_minutes=$((duration_secs / 60))

    # Filter: skip sessions with <1 minute duration
    if [[ "$duration_secs" -lt 60 ]]; then
      continue
    fi

    # Collect tools_used and tokens
    local tools_used input_tokens output_tokens
    tools_used=$(echo "$responses" | jq -c '
      [.[] | .payload.tools_used // [] | .[]] | unique
    ')
    input_tokens=$(echo "$responses" | jq '
      [.[] | .payload.tokens.input // 0] | add // 0
    ')
    output_tokens=$(echo "$responses" | jq '
      [.[] | .payload.tokens.output // 0] | add // 0
    ')

    # Build session JSON
    local session_obj
    session_obj=$(jq -n \
      --arg sid "$session_id" \
      --arg st "$start_time" \
      --arg et "$end_time" \
      --argjson dm "$duration_minutes" \
      --argjson uc "$user_count" \
      --argjson ac "$assistant_count" \
      --argjson tm "$total_messages" \
      --argjson tu "$tools_used" \
      --arg pp "$project_path" \
      --arg gb "$git_branch" \
      --argjson it "$input_tokens" \
      --argjson ot "$output_tokens" \
      --arg md "$model_name" \
      '{
        session_id: $sid,
        start_time: $st,
        end_time: $et,
        duration_minutes: $dm,
        user_message_count: $uc,
        assistant_message_count: $ac,
        total_messages: $tm,
        tools_used: $tu,
        project_path: (if $pp == "null" then null else $pp end),
        git_branch: (if $gb == "null" then null else $gb end),
        input_tokens: $it,
        output_tokens: $ot,
        model: (if $md == "null" then null else $md end)
      }')

    sessions_json=$(echo "$sessions_json" | jq --argjson obj "$session_obj" '. + [$obj]')
  done

  # Sort by start_time descending and apply limit
  echo "$sessions_json" | jq --argjson limit "$limit" --arg cutoff "$cutoff_date" '
    [.[] | select(.start_time >= $cutoff)] | sort_by(.start_time) | reverse | if $limit > 0 then .[:$limit] else . end
  '
}

# --- Main ---

main() {
  local cli_type=""
  local session_dir=""
  local limit=0
  local days=30

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cli)
        [[ $# -lt 2 ]] && die "--cli requires a value"
        cli_type="$2"
        shift 2
        ;;
      --session-dir)
        [[ $# -lt 2 ]] && die "--session-dir requires a value"
        session_dir="$2"
        shift 2
        ;;
      --limit)
        [[ $# -lt 2 ]] && die "--limit requires a value"
        limit="$2"
        shift 2
        ;;
      --days)
        [[ $# -lt 2 ]] && die "--days requires a value"
        days="$2"
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

  require_jq

  # Auto-detect CLI if not specified
  if [[ -z "$cli_type" ]]; then
    cli_type=$("${SCRIPT_DIR}/detect-cli.sh" 2>/dev/null) || die "Could not auto-detect CLI type. Use --cli flag."
  fi

  # Dispatch to appropriate adapter
  case "$cli_type" in
    claude-code)
      local dir="${session_dir:-${HOME}/.claude/projects}"
      collect_claude_code "$dir" "$limit" "$days"
      ;;
    opencode)
      local dir="${session_dir:-${HOME}/.local/share/opencode/storage}"
      collect_opencode "$dir" "$limit" "$days"
      ;;
    codex)
      local dir="${session_dir:-${HOME}/.codex/sessions}"
      collect_codex "$dir" "$limit" "$days"
      ;;
    *)
      die "Unsupported CLI type: $cli_type (supported: claude-code, opencode, codex)"
      ;;
  esac
}

main "$@"
