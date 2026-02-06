#!/usr/bin/env bats

# End-to-end integration tests for the full insights pipeline
# Tests the complete flow: detect-cli → collect-sessions → aggregate-stats → generate-report
# Uses fixture data from tests/fixtures/

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR

  SKILL_DIR="${BATS_TEST_DIRNAME}/.."
  SCRIPTS_DIR="${SKILL_DIR}/scripts"
  FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

  # Mock insights JSON with all 8 sections populated
  MOCK_INSIGHTS='{
    "at_a_glance": {
      "whats_working": "Test working",
      "whats_hindering": "Test hindering",
      "quick_wins": "Test quick wins",
      "ambitious_workflows": "Test ambitious"
    },
    "project_areas": {
      "areas": [
        {"name": "Test Area", "session_count": 5, "description": "Test description"}
      ]
    },
    "interaction_style": {
      "narrative": "Test narrative",
      "key_pattern": "Test pattern"
    },
    "what_works": {
      "workflows": [
        {"title": "Test workflow", "description": "Test description"}
      ]
    },
    "friction_analysis": {
      "categories": [
        {"name": "Test friction", "examples": [{"issue": "Test issue", "impact": "Test impact"}]}
      ]
    },
    "suggestions": {
      "features": ["Test feature"],
      "usage_patterns": ["Test pattern"]
    },
    "on_the_horizon": {
      "opportunities": [
        {"title": "Test opportunity", "description": "Test description", "copyable_prompt": "Test prompt"}
      ]
    },
    "fun_ending": {
      "headline": "Test headline",
      "detail": "Test detail"
    }
  }'
}

teardown() {
  if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Helper: run full pipeline for a given CLI type and fixture dir, produce HTML report
# Sets REPORT_FILE to the generated report path
run_full_pipeline() {
  local cli_type="$1"
  local fixture_dir="$2"
  local report_path="${TEST_TEMP_DIR}/e2e-${cli_type}.html"

  # Step 1: Detect CLI
  run bash "${SCRIPTS_DIR}/detect-cli.sh" --cli "$cli_type"
  [ "$status" -eq 0 ]
  [ "$output" = "$cli_type" ]

  # Step 2: Collect sessions
  local sessions
  sessions=$(bash "${SCRIPTS_DIR}/collect-sessions.sh" --cli "$cli_type" --session-dir "$fixture_dir")
  # Verify valid JSON array with at least 1 session
  echo "$sessions" | jq empty
  local session_count
  session_count=$(echo "$sessions" | jq 'length')
  [ "$session_count" -ge 1 ]

  # Step 3: Aggregate stats
  local stats
  stats=$(echo "$sessions" | bash "${SCRIPTS_DIR}/aggregate-stats.sh")
  echo "$stats" | jq empty
  # Verify essential stat fields
  local total_sessions
  total_sessions=$(echo "$stats" | jq '.total_sessions')
  [ "$total_sessions" -ge 1 ]

  # Step 4: Generate report with mock insights
  local stats_file="${TEST_TEMP_DIR}/stats-${cli_type}.json"
  echo "$stats" > "$stats_file"

  local result
  result=$(echo "$MOCK_INSIGHTS" | bash "${SCRIPTS_DIR}/generate-report.sh" \
    --stats "$stats_file" \
    --cli "$cli_type" \
    --output "$report_path")

  [ "$result" = "$report_path" ]
  [ -f "$report_path" ]

  REPORT_FILE="$report_path"
}

# --- E2E Pipeline Tests ---

@test "E2E: Claude Code full pipeline produces valid HTML report" {
  run_full_pipeline "claude-code" "${FIXTURES_DIR}/claude-code"

  # Verify HTML structure
  run head -n 1 "$REPORT_FILE"
  [[ "$output" =~ "<!DOCTYPE html>" ]]

  # Verify file size is reasonable (>1KB, <5MB)
  local file_size
  file_size=$(wc -c < "$REPORT_FILE" | tr -d ' ')
  [ "$file_size" -gt 1024 ]
  [ "$file_size" -lt 5242880 ]

  # Verify no unreplaced placeholders
  local content
  content=$(cat "$REPORT_FILE")
  [[ ! "$content" =~ "{{STATS_JSON}}" ]]
  [[ ! "$content" =~ "{{INSIGHTS_JSON}}" ]]
  [[ ! "$content" =~ "{{GENERATED_DATE}}" ]]
  [[ ! "$content" =~ "{{CLI_TYPE}}" ]]

  # Verify CLI type injected
  [[ "$content" =~ "claude-code" ]]
}

@test "E2E: OpenCode full pipeline produces valid HTML report" {
  run_full_pipeline "opencode" "${FIXTURES_DIR}/opencode"

  # Verify HTML structure
  run head -n 1 "$REPORT_FILE"
  [[ "$output" =~ "<!DOCTYPE html>" ]]

  # Verify file size is reasonable
  local file_size
  file_size=$(wc -c < "$REPORT_FILE" | tr -d ' ')
  [ "$file_size" -gt 1024 ]
  [ "$file_size" -lt 5242880 ]

  # Verify no unreplaced placeholders
  local content
  content=$(cat "$REPORT_FILE")
  [[ ! "$content" =~ "{{STATS_JSON}}" ]]
  [[ ! "$content" =~ "{{INSIGHTS_JSON}}" ]]
  [[ ! "$content" =~ "{{GENERATED_DATE}}" ]]
  [[ ! "$content" =~ "{{CLI_TYPE}}" ]]

  # Verify CLI type injected
  [[ "$content" =~ "opencode" ]]
}

@test "E2E: Codex full pipeline produces valid HTML report" {
  run_full_pipeline "codex" "${FIXTURES_DIR}/codex"

  # Verify HTML structure
  run head -n 1 "$REPORT_FILE"
  [[ "$output" =~ "<!DOCTYPE html>" ]]

  # Verify file size is reasonable
  local file_size
  file_size=$(wc -c < "$REPORT_FILE" | tr -d ' ')
  [ "$file_size" -gt 1024 ]
  [ "$file_size" -lt 5242880 ]

  # Verify no unreplaced placeholders
  local content
  content=$(cat "$REPORT_FILE")
  [[ ! "$content" =~ "{{STATS_JSON}}" ]]
  [[ ! "$content" =~ "{{INSIGHTS_JSON}}" ]]
  [[ ! "$content" =~ "{{GENERATED_DATE}}" ]]
  [[ ! "$content" =~ "{{CLI_TYPE}}" ]]

  # Verify CLI type injected
  [[ "$content" =~ "codex" ]]
}

@test "E2E: Report contains all required data sections" {
  # Run Claude Code pipeline (representative)
  run_full_pipeline "claude-code" "${FIXTURES_DIR}/claude-code"

  local content
  content=$(cat "$REPORT_FILE")

  # Verify report structural elements
  [[ "$content" =~ "Insights Report" ]]
  [[ "$content" =~ "stats-data" ]]
  [[ "$content" =~ "insights-data" ]]
  [[ "$content" =~ "report-content" ]]

  # Verify stats data was injected (check for a stats key)
  [[ "$content" =~ "total_sessions" ]]

  # Verify insights data was injected (check for mock values)
  [[ "$content" =~ "at_a_glance" ]]
  [[ "$content" =~ "Test working" ]]
  [[ "$content" =~ "Test hindering" ]]
  [[ "$content" =~ "Test quick wins" ]]
  [[ "$content" =~ "Test ambitious" ]]
  [[ "$content" =~ "Test narrative" ]]
  [[ "$content" =~ "Test workflow" ]]
  [[ "$content" =~ "Test friction" ]]
  [[ "$content" =~ "Test feature" ]]
  [[ "$content" =~ "Test opportunity" ]]
  [[ "$content" =~ "Test headline" ]]
  [[ "$content" =~ "Test detail" ]]

  # Verify generated date is present (current date in ISO format)
  local current_date
  current_date=$(date -u +"%Y-%m-%d")
  [[ "$content" =~ "$current_date" ]]
}

@test "E2E: Pipeline stats reflect actual fixture data" {
  # Run Claude Code pipeline and verify stats match fixtures
  local sessions
  sessions=$(bash "${SCRIPTS_DIR}/collect-sessions.sh" --cli claude-code --session-dir "${FIXTURES_DIR}/claude-code")

  local stats
  stats=$(echo "$sessions" | bash "${SCRIPTS_DIR}/aggregate-stats.sh")

  # Stats should reflect actual session count from fixtures
  local total_sessions session_count
  total_sessions=$(echo "$stats" | jq '.total_sessions')
  session_count=$(echo "$sessions" | jq 'length')
  [ "$total_sessions" -eq "$session_count" ]

  # Total messages should be > 0
  local total_messages
  total_messages=$(echo "$stats" | jq '.total_messages')
  [ "$total_messages" -gt 0 ]

  # Duration should be > 0
  local duration
  duration=$(echo "$stats" | jq '.total_duration_hours')
  [[ "$duration" != "0" ]]

  # Date range should be set
  local start_date end_date
  start_date=$(echo "$stats" | jq -r '.date_range.start')
  end_date=$(echo "$stats" | jq -r '.date_range.end')
  [[ "$start_date" != "null" ]]
  [[ "$end_date" != "null" ]]
}
