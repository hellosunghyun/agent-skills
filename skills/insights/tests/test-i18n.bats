#!/usr/bin/env bats

# Test suite for i18n (internationalization) functionality
# Tests multi-language report generation with locale files

setup() {
  # Create temp directory for test outputs
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  
  # Path to script under test
  SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/generate-report.sh"
  LOCALES_DIR="${BATS_TEST_DIRNAME}/../scripts/locales"
  
  # Sample stats JSON
  STATS_JSON='{
    "total_sessions": 42,
    "date_range": {"start": "2026-01-01", "end": "2026-02-06"},
    "total_messages": 500,
    "total_duration_minutes": 750,
    "total_input_tokens": 250000,
    "total_output_tokens": 150000,
    "tool_counts": {"bash": 120, "edit": 80},
    "languages": {"TypeScript": 150},
    "git_commits": 25,
    "projects": {"/Users/user/project1": 30}
  }'
  
  # Sample insights JSON
  INSIGHTS_JSON='{
    "at_a_glance": {
      "whats_working": "Fast iteration cycles",
      "whats_hindering": "Context switching",
      "quick_wins": "Use keyboard shortcuts",
      "ambitious_workflows": "Automated testing pipeline"
    },
    "project_areas": {
      "areas": [
        {"name": "Backend API", "session_count": 20, "description": "REST API development"},
        {"name": "Frontend", "session_count": 15, "description": "React components"}
      ]
    },
    "interaction_style": {
      "narrative": "You prefer direct, concise communication.",
      "key_pattern": "Iterative refinement"
    },
    "what_works": {
      "workflows": [
        {"title": "TDD Workflow", "description": "Write tests first, then implement"}
      ]
    },
    "friction_analysis": {
      "categories": [
        {
          "name": "Context Loss",
          "examples": [
            {"issue": "Forgot previous decision", "impact": "Rework needed"}
          ]
        }
      ]
    },
    "suggestions": {
      "features": ["Try parallel execution"],
      "usage_patterns": ["Use more keyboard shortcuts"]
    },
    "on_the_horizon": {
      "opportunities": [
        {
          "title": "Automated Refactoring",
          "description": "Use AST tools for safe refactoring",
          "copyable_prompt": "Refactor this function using AST grep"
        }
      ]
    },
    "fun_ending": {
      "headline": "You shipped 25 commits!",
      "detail": "That is impressive productivity."
    }
  }'
  
  # Create temp stats file
  STATS_FILE="${TEST_TEMP_DIR}/stats.json"
  echo "$STATS_JSON" > "$STATS_FILE"
}

teardown() {
  # Clean up temp directory
  rm -rf "$TEST_TEMP_DIR"
}

# --- Locale File Validation Tests ---

@test "locale files are valid JSON" {
  # English locale
  python3 -c "import json; json.load(open('${LOCALES_DIR}/en.json'))"
  
  # Korean locale
  python3 -c "import json; json.load(open('${LOCALES_DIR}/ko.json'))"
}

@test "locale files have identical keys" {
  # Load both locale files and compare key sets
  run python3 -c "
import json
import sys

with open('${LOCALES_DIR}/en.json') as f:
    en_keys = set(json.load(f).keys())

with open('${LOCALES_DIR}/ko.json') as f:
    ko_keys = set(json.load(f).keys())

if en_keys != ko_keys:
    missing_in_ko = en_keys - ko_keys
    missing_in_en = ko_keys - en_keys
    if missing_in_ko:
        print(f'Missing in ko.json: {missing_in_ko}', file=sys.stderr)
    if missing_in_en:
        print(f'Missing in en.json: {missing_in_en}', file=sys.stderr)
    sys.exit(1)
"
  
  [ "$status" -eq 0 ]
}

# --- Korean Report Generation Tests ---

@test "Korean report generation succeeds" {
  output_file="${TEST_TEMP_DIR}/report-ko.html"
  
  result=$(echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language ko --output "$output_file")
  
  # Should output the file path
  [ "$result" = "$output_file" ]
  
  # File should exist
  [ -f "$output_file" ]
}

@test "Korean report contains Korean strings" {
  output_file="${TEST_TEMP_DIR}/report-ko.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language ko --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Check for Korean strings (from ko.json)
  [[ "$content" =~ "인사이트 리포트" ]]  # Insights Report
  [[ "$content" =~ "한눈에 보기" ]]      # At a Glance
  [[ "$content" =~ "잘 되고 있는 것" ]]  # What's Working
}

# --- English Report Generation Tests ---

@test "English report generation succeeds" {
  output_file="${TEST_TEMP_DIR}/report-en.html"
  
  result=$(echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language en --output "$output_file")
  
  # Should output the file path
  [ "$result" = "$output_file" ]
  
  # File should exist
  [ -f "$output_file" ]
}

@test "English report contains English strings" {
  output_file="${TEST_TEMP_DIR}/report-en.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language en --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Check for English strings (from en.json)
  [[ "$content" =~ "Insights Report" ]]
  [[ "$content" =~ "At a Glance" ]]
  [[ "$content" =~ "What's Working" ]]
}

# --- Default Language Tests ---

@test "default language is English when no flag specified" {
  output_file="${TEST_TEMP_DIR}/report-default.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should contain English strings
  [[ "$content" =~ "Insights Report" ]]
  [[ "$content" =~ "At a Glance" ]]
  
  # Should have lang="en" attribute
  [[ "$content" =~ 'lang="en"' ]]
}

@test "LANG environment variable affects default language" {
  output_file="${TEST_TEMP_DIR}/report-lang-env.html"
  
  # Set LANG to Korean locale
  LANG=ko_KR.UTF-8 bash -c "echo '$INSIGHTS_JSON' | '$SCRIPT_PATH' --stats '$STATS_FILE' --cli 'claude-code' --output '$output_file'"
  
  content=$(cat "$output_file")
  
  # Should contain Korean strings
  [[ "$content" =~ "인사이트 리포트" ]]
}

@test "LANG=C falls back to English" {
  output_file="${TEST_TEMP_DIR}/report-lang-c.html"
  
  # Set LANG to C (POSIX locale)
  LANG=C bash -c "echo '$INSIGHTS_JSON' | '$SCRIPT_PATH' --stats '$STATS_FILE' --cli 'claude-code' --output '$output_file'"
  
  content=$(cat "$output_file")
  
  # Should contain English strings (fallback)
  [[ "$content" =~ "Insights Report" ]]
  [[ "$content" =~ "At a Glance" ]]
}

# --- Unknown Language Fallback Tests ---

@test "unknown language falls back to English with warning" {
  output_file="${TEST_TEMP_DIR}/report-unknown.html"
  
  # Use non-existent language code
  run bash -c "echo '$INSIGHTS_JSON' | '$SCRIPT_PATH' --stats '$STATS_FILE' --cli 'claude-code' --language zz --output '$output_file' 2>&1"
  
  # Should warn about unknown language
  [[ "$output" =~ "Warning" ]] || [[ "$output" =~ "not found" ]] || [[ "$output" =~ "fallback" ]]
  
  # File should still be generated
  [ -f "$output_file" ]
  
  content=$(cat "$output_file")
  
  # Should contain English strings (fallback)
  [[ "$content" =~ "Insights Report" ]]
}

# --- Placeholder Replacement Tests ---

@test "no unreplaced locale placeholders in Korean report" {
  output_file="${TEST_TEMP_DIR}/report-ko-placeholders.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language ko --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should NOT contain any unreplaced locale placeholders
  [[ ! "$content" =~ "{{LOCALE_JSON}}" ]]
  [[ ! "$content" =~ "{{LANGUAGE_CODE}}" ]]
}

@test "no unreplaced locale placeholders in English report" {
  output_file="${TEST_TEMP_DIR}/report-en-placeholders.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language en --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should NOT contain any unreplaced locale placeholders
  [[ ! "$content" =~ "{{LOCALE_JSON}}" ]]
  [[ ! "$content" =~ "{{LANGUAGE_CODE}}" ]]
}

# --- HTML Lang Attribute Tests ---

@test "HTML lang attribute is correct for Korean" {
  output_file="${TEST_TEMP_DIR}/report-ko-lang.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language ko --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should have lang="ko" attribute
  [[ "$content" =~ 'lang="ko"' ]]
}

@test "HTML lang attribute is correct for English" {
  output_file="${TEST_TEMP_DIR}/report-en-lang.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --language en --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should have lang="en" attribute
  [[ "$content" =~ 'lang="en"' ]]
}

# --- Full Pipeline E2E Korean Test ---

@test "full pipeline E2E with Korean language" {
  # This test simulates the full pipeline with Korean language
  FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"
  SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../scripts"
  
  # Skip if fixtures don't exist
  if [ ! -d "${FIXTURES_DIR}/claude-code" ]; then
    skip "Fixture directory not found"
  fi
  
  # Step 1: Detect CLI
  cli_type="claude-code"
  run bash "${SCRIPTS_DIR}/detect-cli.sh" --cli "$cli_type"
  [ "$status" -eq 0 ]
  
  # Step 2: Collect sessions
  sessions=$(bash "${SCRIPTS_DIR}/collect-sessions.sh" --cli "$cli_type" --session-dir "${FIXTURES_DIR}/claude-code")
  echo "$sessions" | jq empty
  
  # Step 3: Aggregate stats
  stats=$(echo "$sessions" | bash "${SCRIPTS_DIR}/aggregate-stats.sh")
  echo "$stats" | jq empty
  
  # Step 4: Generate Korean report
  stats_file="${TEST_TEMP_DIR}/stats-ko.json"
  echo "$stats" > "$stats_file"
  
  output_file="${TEST_TEMP_DIR}/e2e-ko.html"
  result=$(echo "$INSIGHTS_JSON" | bash "${SCRIPTS_DIR}/generate-report.sh" \
    --stats "$stats_file" \
    --cli "$cli_type" \
    --language ko \
    --output "$output_file")
  
  [ "$result" = "$output_file" ]
  [ -f "$output_file" ]
  
  # Verify Korean content
  content=$(cat "$output_file")
  [[ "$content" =~ "인사이트 리포트" ]]
  [[ "$content" =~ 'lang="ko"' ]]
  
  # Verify no placeholders
  [[ ! "$content" =~ "{{LOCALE_JSON}}" ]]
  [[ ! "$content" =~ "{{LANGUAGE_CODE}}" ]]
}
