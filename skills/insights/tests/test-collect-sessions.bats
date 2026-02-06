#!/usr/bin/env bats

# Test suite for collect-sessions.sh

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/collect-sessions.sh"
  FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

  export TEST_TMPDIR="${BATS_TMPDIR}/collect-sessions-test-$$"
  mkdir -p "${TEST_TMPDIR}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# --- Claude Code adapter tests ---

@test "collects Claude Code sessions from fixture data" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code"

  [ "$status" -eq 0 ]
  # Should be valid JSON array
  echo "$output" | jq empty
  # session-cc-001 has 3 user + 3 assistant = 6 messages, 20 min duration → included
  local count
  count=$(echo "$output" | jq 'length')
  [ "$count" -ge 1 ]
  # Verify session-cc-001 is present
  echo "$output" | jq -e '.[] | select(.session_id == "session-cc-001")' >/dev/null
}

@test "Claude Code: extracts correct metadata fields" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code"

  [ "$status" -eq 0 ]
  local session
  session=$(echo "$output" | jq '.[] | select(.session_id == "session-cc-001")')

  # Check required fields exist and have correct values
  [ "$(echo "$session" | jq -r '.session_id')" = "session-cc-001" ]
  [ "$(echo "$session" | jq -r '.start_time')" = "2026-02-01T10:00:00.000Z" ]
  [ "$(echo "$session" | jq -r '.end_time')" = "2026-02-01T10:20:00.000Z" ]
  [ "$(echo "$session" | jq '.duration_minutes')" = "20" ]
  [ "$(echo "$session" | jq '.user_message_count')" = "3" ]
  [ "$(echo "$session" | jq '.assistant_message_count')" = "3" ]
  [ "$(echo "$session" | jq '.total_messages')" = "6" ]
  [ "$(echo "$session" | jq -r '.project_path')" = "/Users/user/myproject" ]
  [ "$(echo "$session" | jq -r '.git_branch')" = "main" ]
  # tools_used should contain Read, Write, Bash
  echo "$session" | jq -e '.tools_used | length > 0' >/dev/null
}

@test "Claude Code: filters sessions with <2 messages" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code"

  [ "$status" -eq 0 ]
  # session-cc-short has only 1 message → should be filtered
  local found
  found=$(echo "$output" | jq '[.[] | select(.session_id == "session-cc-short")] | length')
  [ "$found" -eq 0 ]
}

@test "Claude Code: filters sessions with <1 minute duration" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code"

  [ "$status" -eq 0 ]
  # session-cc-quick has 2 messages but only 30 seconds duration → should be filtered
  local found
  found=$(echo "$output" | jq '[.[] | select(.session_id == "session-cc-quick")] | length')
  [ "$found" -eq 0 ]
}

@test "Claude Code: filters agent sub-sessions" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code"

  [ "$status" -eq 0 ]
  # session-agent-001 is in agent-task-001 directory → should be filtered
  local found
  found=$(echo "$output" | jq '[.[] | select(.session_id == "session-agent-001")] | length')
  [ "$found" -eq 0 ]
}

# --- OpenCode adapter tests ---

@test "collects OpenCode sessions from fixture data" {
  run bash "${SCRIPT}" --cli opencode --session-dir "${FIXTURES_DIR}/opencode"

  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  # session-oc-001 has 4 messages, 30 min duration → included
  echo "$output" | jq -e '.[] | select(.session_id == "session-oc-001")' >/dev/null
}

@test "OpenCode: extracts correct metadata fields" {
  run bash "${SCRIPT}" --cli opencode --session-dir "${FIXTURES_DIR}/opencode"

  [ "$status" -eq 0 ]
  local session
  session=$(echo "$output" | jq '.[] | select(.session_id == "session-oc-001")')

  [ "$(echo "$session" | jq -r '.session_id')" = "session-oc-001" ]
  [ "$(echo "$session" | jq '.user_message_count')" = "2" ]
  [ "$(echo "$session" | jq '.assistant_message_count')" = "2" ]
  [ "$(echo "$session" | jq '.total_messages')" = "4" ]
  [ "$(echo "$session" | jq -r '.project_path')" = "/Users/user/opencode-project" ]
  [ "$(echo "$session" | jq '.duration_minutes')" = "30" ]
  # Check tokens are summed
  [ "$(echo "$session" | jq '.input_tokens')" = "1280" ]
  [ "$(echo "$session" | jq '.output_tokens')" = "500" ]
  [ "$(echo "$session" | jq -r '.model')" = "claude-sonnet-4-20250514" ]
}

@test "OpenCode: filters sessions with <2 messages" {
  run bash "${SCRIPT}" --cli opencode --session-dir "${FIXTURES_DIR}/opencode"

  [ "$status" -eq 0 ]
  # session-oc-short has only 1 message → should be filtered
  local found
  found=$(echo "$output" | jq '[.[] | select(.session_id == "session-oc-short")] | length')
  [ "$found" -eq 0 ]
}

# --- Codex adapter tests ---

@test "collects Codex sessions from fixture data" {
  run bash "${SCRIPT}" --cli codex --session-dir "${FIXTURES_DIR}/codex"

  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  # rollout-001 has multiple response_items → included
  echo "$output" | jq -e '.[] | select(.session_id == "rollout-001")' >/dev/null
}

@test "Codex: extracts correct metadata fields" {
  run bash "${SCRIPT}" --cli codex --session-dir "${FIXTURES_DIR}/codex"

  [ "$status" -eq 0 ]
  local session
  session=$(echo "$output" | jq '.[] | select(.session_id == "rollout-001")')

  [ "$(echo "$session" | jq -r '.session_id')" = "rollout-001" ]
  [ "$(echo "$session" | jq -r '.start_time')" = "2026-02-01T09:00:00.000Z" ]
  [ "$(echo "$session" | jq -r '.end_time')" = "2026-02-01T09:10:00.000Z" ]
  [ "$(echo "$session" | jq '.duration_minutes')" = "10" ]
  [ "$(echo "$session" | jq -r '.project_path')" = "/Users/user/codex-project" ]
  [ "$(echo "$session" | jq -r '.git_branch')" = "feature-x" ]
  [ "$(echo "$session" | jq -r '.model')" = "o3-mini" ]
  # tools_used should be collected from all response_items
  echo "$session" | jq -e '.tools_used | length > 0' >/dev/null
}

@test "Codex: filters sessions with <1 minute duration" {
  run bash "${SCRIPT}" --cli codex --session-dir "${FIXTURES_DIR}/codex"

  [ "$status" -eq 0 ]
  # rollout-short has only 20 seconds duration → should be filtered
  local found
  found=$(echo "$output" | jq '[.[] | select(.session_id == "rollout-short")] | length')
  [ "$found" -eq 0 ]
}

# --- Edge cases ---

@test "handles empty session directory gracefully" {
  mkdir -p "${TEST_TMPDIR}/empty-dir"

  run bash "${SCRIPT}" --cli claude-code --session-dir "${TEST_TMPDIR}/empty-dir"

  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  local count
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 0 ]
}

@test "handles malformed JSONL files gracefully" {
  # The broken fixture has invalid JSON lines
  mkdir -p "${TEST_TMPDIR}/malformed/-Users-user-broken"
  cp "${FIXTURES_DIR}/claude-code/-Users-user-broken/session-malformed.jsonl" \
     "${TEST_TMPDIR}/malformed/-Users-user-broken/"

  run bash "${SCRIPT}" --cli claude-code --session-dir "${TEST_TMPDIR}/malformed"

  # Should not crash — exit 0 with empty or filtered results
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
}

@test "--limit flag restricts number of sessions returned" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code" --limit 1

  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  local count
  count=$(echo "$output" | jq 'length')
  [ "$count" -le 1 ]
}

@test "output is sorted by start_time descending" {
  run bash "${SCRIPT}" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code"

  [ "$status" -eq 0 ]
  # If multiple sessions pass filters, first should have later start_time
  local count
  count=$(echo "$output" | jq 'length')
  if [ "$count" -gt 1 ]; then
    local first_time second_time
    first_time=$(echo "$output" | jq -r '.[0].start_time')
    second_time=$(echo "$output" | jq -r '.[1].start_time')
    # first_time should be >= second_time (descending)
    [[ "$first_time" > "$second_time" ]] || [[ "$first_time" == "$second_time" ]]
  fi
}

@test "shows help with --help flag" {
  run bash "${SCRIPT}" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"collect-sessions"* ]]
}
