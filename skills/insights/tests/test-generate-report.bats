#!/usr/bin/env bats

# Test suite for generate-report.sh

setup() {
  # Create temp directory for test outputs
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
  
  # Path to script under test
  SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/generate-report.sh"
  
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

@test "script exists and is executable" {
  [ -x "$SCRIPT_PATH" ]
}

@test "generates valid HTML from sample data" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  result=$(echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file")
  
  # Should output the file path
  [ "$result" = "$output_file" ]
  
  # File should exist
  [ -f "$output_file" ]
  
  # Should be valid HTML (starts with DOCTYPE)
  run head -n 1 "$output_file"
  [[ "$output" =~ "<!DOCTYPE html>" ]]
}

@test "HTML contains all required sections" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "opencode" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Check for key structural elements
  [[ "$content" =~ "Insights Report" ]]
  [[ "$content" =~ "stats-data" ]]
  [[ "$content" =~ "insights-data" ]]
  [[ "$content" =~ "report-content" ]]
}

@test "injects stats JSON correctly" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "codex" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Stats JSON should be present (check for a unique value)
  [[ "$content" =~ "total_sessions" ]]
  [[ "$content" =~ "42" ]]
}

@test "injects insights JSON correctly" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Insights JSON should be present (check for unique values)
  [[ "$content" =~ "at_a_glance" ]]
  [[ "$content" =~ "Fast iteration cycles" ]]
  [[ "$content" =~ "Backend API" ]]
}

@test "injects generated date correctly" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should contain current date in ISO format (YYYY-MM-DD)
  current_date=$(date -u +"%Y-%m-%d")
  [[ "$content" =~ "$current_date" ]]
}

@test "injects CLI type correctly" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "opencode" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should contain CLI type
  [[ "$content" =~ "opencode" ]]
}

@test "no placeholders remain in output" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should NOT contain any unreplaced placeholders
  [[ ! "$content" =~ "{{STATS_JSON}}" ]]
  [[ ! "$content" =~ "{{INSIGHTS_JSON}}" ]]
  [[ ! "$content" =~ "{{GENERATED_DATE}}" ]]
  [[ ! "$content" =~ "{{CLI_TYPE}}" ]]
}

@test "handles missing stats file gracefully" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  run bash -c "echo '$INSIGHTS_JSON' | '$SCRIPT_PATH' --stats '/nonexistent/file.json' --cli 'claude-code' --output '$output_file'"
  
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Stats file not found" ]] || [[ "$output" =~ "not found" ]]
}

@test "uses default output path when --output not specified" {
  default_output="./insights-report.html"
  
  # Clean up any existing default file
  rm -f "$default_output"
  
  result=$(echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code")
  
  # Should output default path
  [ "$result" = "$default_output" ]
  
  # File should exist
  [ -f "$default_output" ]
  
  # Clean up
  rm -f "$default_output"
}

@test "file size is reasonable (>1KB, <5MB)" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  echo "$INSIGHTS_JSON" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file"
  
  # Get file size in bytes
  file_size=$(wc -c < "$output_file" | tr -d ' ')
  
  # Should be > 1KB (1024 bytes)
  [ "$file_size" -gt 1024 ]
  
  # Should be < 5MB (5242880 bytes)
  [ "$file_size" -lt 5242880 ]
}

@test "handles special characters in JSON correctly" {
  output_file="${TEST_TEMP_DIR}/report.html"
  
  # JSON with special characters that could break sed
  special_insights='{
    "at_a_glance": {
      "whats_working": "Using \"quotes\" and /slashes/ & ampersands",
      "whats_hindering": "Backslashes \\ are tricky",
      "quick_wins": "Line\nbreaks\nwork",
      "ambitious_workflows": "Special chars: $VAR ${VAR} `cmd`"
    },
    "project_areas": {"areas": []},
    "interaction_style": {"narrative": "Test", "key_pattern": "Test"},
    "what_works": {"workflows": []},
    "friction_analysis": {"categories": []},
    "suggestions": {"features": [], "usage_patterns": []},
    "on_the_horizon": {"opportunities": []},
    "fun_ending": {"headline": "Test", "detail": "Test"}
  }'
  
  echo "$special_insights" | "$SCRIPT_PATH" --stats "$STATS_FILE" --cli "claude-code" --output "$output_file"
  
  content=$(cat "$output_file")
  
  # Should contain the special characters (properly escaped)
  [[ "$content" =~ "quotes" ]]
  [[ "$content" =~ "slashes" ]]
  [[ "$content" =~ "ampersands" ]]
}

@test "shows help with -h flag" {
  run "$SCRIPT_PATH" -h
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]] || [[ "$output" =~ "OPTIONS:" ]]
}
