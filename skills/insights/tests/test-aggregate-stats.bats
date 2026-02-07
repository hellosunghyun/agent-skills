#!/usr/bin/env bats

# Test suite for aggregate-stats.sh
# Tests aggregation of session metadata into statistics

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  AGGREGATE_SCRIPT="${SCRIPT_DIR}/scripts/aggregate-stats.sh"
  
  # Ensure script exists
  [[ -f "$AGGREGATE_SCRIPT" ]] || skip "aggregate-stats.sh not found"
}

@test "aggregate-stats.sh: handles empty array" {
  result=$(echo '[]' | bash "$AGGREGATE_SCRIPT")
  
  # Should return valid JSON with zero values
  total_sessions=$(echo "$result" | jq -r '.total_sessions')
  [[ "$total_sessions" == "0" ]]
  
  total_messages=$(echo "$result" | jq -r '.total_messages')
  [[ "$total_messages" == "0" ]]
}

@test "aggregate-stats.sh: handles single session" {
  input='[{
    "session_id": "test1",
    "start_time": "2026-02-06T10:00:00.000Z",
    "end_time": "2026-02-06T10:15:00.000Z",
    "duration_minutes": 15,
    "user_message_count": 5,
    "assistant_message_count": 5,
    "total_messages": 10,
    "tools_used": ["bash", "edit"],
    "project_path": "/Users/test/project",
    "git_branch": "main",
    "input_tokens": 5000,
    "output_tokens": 3000,
    "model": "claude-sonnet-4"
  }]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Verify basic counts
  total_sessions=$(echo "$result" | jq -r '.total_sessions')
  [[ "$total_sessions" == "1" ]]
  
  total_messages=$(echo "$result" | jq -r '.total_messages')
  [[ "$total_messages" == "10" ]]
  
  # Verify duration (15 minutes = 0.25 hours)
  duration=$(echo "$result" | jq -r '.total_duration_hours')
  [[ "$duration" == "0.25" ]]
  
  # Verify tokens
  input_tokens=$(echo "$result" | jq -r '.total_input_tokens')
  [[ "$input_tokens" == "5000" ]]
  
  output_tokens=$(echo "$result" | jq -r '.total_output_tokens')
  [[ "$output_tokens" == "3000" ]]
  
  # Verify date range
  start_date=$(echo "$result" | jq -r '.date_range.start')
  [[ "$start_date" == "2026-02-06" ]]
  
  end_date=$(echo "$result" | jq -r '.date_range.end')
  [[ "$end_date" == "2026-02-06" ]]
  
  # Verify days active
  days_active=$(echo "$result" | jq -r '.days_active')
  [[ "$days_active" == "1" ]]
  
  # Verify messages per day
  messages_per_day=$(echo "$result" | jq -r '.messages_per_day')
  [[ "$messages_per_day" == "10" ]]
}

@test "aggregate-stats.sh: aggregates multiple sessions" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-01T10:00:00.000Z",
      "end_time": "2026-02-01T10:30:00.000Z",
      "duration_minutes": 30,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash", "edit"],
      "project_path": "/Users/test/project1",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-03T14:00:00.000Z",
      "end_time": "2026-02-03T14:45:00.000Z",
      "duration_minutes": 45,
      "user_message_count": 8,
      "assistant_message_count": 7,
      "total_messages": 15,
      "tools_used": ["bash", "read", "write"],
      "project_path": "/Users/test/project2",
      "git_branch": "feature",
      "input_tokens": 8000,
      "output_tokens": 5000,
      "model": "claude-opus-4"
    }
  ]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Verify totals
  total_sessions=$(echo "$result" | jq -r '.total_sessions')
  [[ "$total_sessions" == "2" ]]
  
  total_messages=$(echo "$result" | jq -r '.total_messages')
  [[ "$total_messages" == "25" ]]
  
  # Verify duration (30 + 45 = 75 minutes = 1.25 hours)
  duration=$(echo "$result" | jq -r '.total_duration_hours')
  [[ "$duration" == "1.25" ]]
  
  # Verify tokens
  input_tokens=$(echo "$result" | jq -r '.total_input_tokens')
  [[ "$input_tokens" == "13000" ]]
  
  output_tokens=$(echo "$result" | jq -r '.total_output_tokens')
  [[ "$output_tokens" == "8000" ]]
  
  # Verify date range
  start_date=$(echo "$result" | jq -r '.date_range.start')
  [[ "$start_date" == "2026-02-01" ]]
  
  end_date=$(echo "$result" | jq -r '.date_range.end')
  [[ "$end_date" == "2026-02-03" ]]
  
  # Verify days active (2 unique days)
  days_active=$(echo "$result" | jq -r '.days_active')
  [[ "$days_active" == "2" ]]
  
  # Verify messages per day (25 / 2 = 12.5)
  messages_per_day=$(echo "$result" | jq -r '.messages_per_day')
  [[ "$messages_per_day" == "12.5" ]]
}

@test "aggregate-stats.sh: counts tools correctly" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-06T10:00:00.000Z",
      "end_time": "2026-02-06T10:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash", "edit", "bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-06T11:00:00.000Z",
      "end_time": "2026-02-06T11:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 3,
      "assistant_message_count": 3,
      "total_messages": 6,
      "tools_used": ["bash", "read"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 3000,
      "output_tokens": 2000,
      "model": "claude-sonnet-4"
    }
  ]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Verify tool counts (bash appears in both sessions, edit in 1, read in 1)
  bash_count=$(echo "$result" | jq -r '.tool_counts.bash')
  [[ "$bash_count" == "2" ]]
  
  edit_count=$(echo "$result" | jq -r '.tool_counts.edit')
  [[ "$edit_count" == "1" ]]
  
  read_count=$(echo "$result" | jq -r '.tool_counts.read')
  [[ "$read_count" == "1" ]]
}

@test "aggregate-stats.sh: counts projects correctly" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-06T10:00:00.000Z",
      "end_time": "2026-02-06T10:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project1",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-06T11:00:00.000Z",
      "end_time": "2026-02-06T11:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 3,
      "assistant_message_count": 3,
      "total_messages": 6,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project1",
      "git_branch": "main",
      "input_tokens": 3000,
      "output_tokens": 2000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test3",
      "start_time": "2026-02-06T12:00:00.000Z",
      "end_time": "2026-02-06T12:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 4,
      "assistant_message_count": 4,
      "total_messages": 8,
      "tools_used": ["edit"],
      "project_path": "/Users/test/project2",
      "git_branch": "feature",
      "input_tokens": 4000,
      "output_tokens": 2500,
      "model": "claude-opus-4"
    }
  ]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Verify project counts
  project1_count=$(echo "$result" | jq -r '.projects["/Users/test/project1"]')
  [[ "$project1_count" == "2" ]]
  
  project2_count=$(echo "$result" | jq -r '.projects["/Users/test/project2"]')
  [[ "$project2_count" == "1" ]]
}

@test "aggregate-stats.sh: calculates message hours distribution" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-06T10:00:00.000Z",
      "end_time": "2026-02-06T10:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-06T14:00:00.000Z",
      "end_time": "2026-02-06T14:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 3,
      "assistant_message_count": 3,
      "total_messages": 6,
      "tools_used": ["edit"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 3000,
      "output_tokens": 2000,
      "model": "claude-sonnet-4"
    }
  ]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Verify message_hours is an array with 24 elements
  hours_length=$(echo "$result" | jq -r '.message_hours | length')
  [[ "$hours_length" == "24" ]]
  
  # Verify hour 10 has 10 messages
  hour_10=$(echo "$result" | jq -r '.message_hours[10]')
  [[ "$hour_10" == "10" ]]
  
  # Verify hour 14 has 6 messages
  hour_14=$(echo "$result" | jq -r '.message_hours[14]')
  [[ "$hour_14" == "6" ]]
  
  # Verify hour 0 has 0 messages
  hour_0=$(echo "$result" | jq -r '.message_hours[0]')
  [[ "$hour_0" == "0" ]]
}

@test "aggregate-stats.sh: outputs valid JSON" {
  input='[{
    "session_id": "test1",
    "start_time": "2026-02-06T10:00:00.000Z",
    "end_time": "2026-02-06T10:15:00.000Z",
    "duration_minutes": 15,
    "user_message_count": 5,
    "assistant_message_count": 5,
    "total_messages": 10,
    "tools_used": ["bash"],
    "project_path": "/Users/test/project",
    "git_branch": "main",
    "input_tokens": 5000,
    "output_tokens": 3000,
    "model": "claude-sonnet-4"
  }]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Verify JSON is valid
  echo "$result" | jq empty
}

@test "aggregate-stats.sh: computes project_breakdown" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-01T10:00:00.000Z",
      "end_time": "2026-02-01T10:30:00.000Z",
      "duration_minutes": 30,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project1",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-03T14:00:00.000Z",
      "end_time": "2026-02-03T14:45:00.000Z",
      "duration_minutes": 45,
      "user_message_count": 8,
      "assistant_message_count": 7,
      "total_messages": 15,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project1",
      "git_branch": "main",
      "input_tokens": 8000,
      "output_tokens": 5000,
      "model": "claude-opus-4"
    }
  ]'

  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")

  sessions=$(echo "$result" | jq -r '.project_breakdown["/Users/test/project1"].sessions')
  [[ "$sessions" == "2" ]]

  messages=$(echo "$result" | jq -r '.project_breakdown["/Users/test/project1"].messages')
  [[ "$messages" == "25" ]]

  duration=$(echo "$result" | jq -r '.project_breakdown["/Users/test/project1"].duration_minutes')
  [[ "$duration" == "75" ]]
}

@test "aggregate-stats.sh: computes model_distribution" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-06T10:00:00.000Z",
      "end_time": "2026-02-06T10:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-06T11:00:00.000Z",
      "end_time": "2026-02-06T11:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 3,
      "assistant_message_count": 3,
      "total_messages": 6,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 3000,
      "output_tokens": 2000,
      "model": "claude-opus-4"
    }
  ]'

  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")

  sonnet=$(echo "$result" | jq -r '.model_distribution["claude-sonnet-4"]')
  [[ "$sonnet" == "1" ]]

  opus=$(echo "$result" | jq -r '.model_distribution["claude-opus-4"]')
  [[ "$opus" == "1" ]]
}

@test "aggregate-stats.sh: computes duration_percentiles" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-06T10:00:00.000Z",
      "end_time": "2026-02-06T10:10:00.000Z",
      "duration_minutes": 10,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-06T11:00:00.000Z",
      "end_time": "2026-02-06T11:30:00.000Z",
      "duration_minutes": 30,
      "user_message_count": 3,
      "assistant_message_count": 3,
      "total_messages": 6,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 3000,
      "output_tokens": 2000,
      "model": "claude-sonnet-4"
    }
  ]'

  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")

  min_val=$(echo "$result" | jq -r '.duration_percentiles.min')
  [[ "$min_val" == "10" ]]

  max_val=$(echo "$result" | jq -r '.duration_percentiles.max')
  [[ "$max_val" == "30" ]]

  avg_val=$(echo "$result" | jq -r '.duration_percentiles.avg')
  [[ "$avg_val" == "20" ]]
}

@test "aggregate-stats.sh: computes daily_activity" {
  input='[
    {
      "session_id": "test1",
      "start_time": "2026-02-01T10:00:00.000Z",
      "end_time": "2026-02-01T10:30:00.000Z",
      "duration_minutes": 30,
      "user_message_count": 5,
      "assistant_message_count": 5,
      "total_messages": 10,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 5000,
      "output_tokens": 3000,
      "model": "claude-sonnet-4"
    },
    {
      "session_id": "test2",
      "start_time": "2026-02-01T14:00:00.000Z",
      "end_time": "2026-02-01T14:15:00.000Z",
      "duration_minutes": 15,
      "user_message_count": 3,
      "assistant_message_count": 3,
      "total_messages": 6,
      "tools_used": ["bash"],
      "project_path": "/Users/test/project",
      "git_branch": "main",
      "input_tokens": 3000,
      "output_tokens": 2000,
      "model": "claude-sonnet-4"
    }
  ]'

  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")

  daily_count=$(echo "$result" | jq -r '.daily_activity | length')
  [[ "$daily_count" == "1" ]]

  daily_sessions=$(echo "$result" | jq -r '.daily_activity[0].sessions')
  [[ "$daily_sessions" == "2" ]]

  daily_messages=$(echo "$result" | jq -r '.daily_activity[0].messages')
  [[ "$daily_messages" == "16" ]]
}

@test "aggregate-stats.sh: computes token_efficiency and message ratios" {
  input='[{
    "session_id": "test1",
    "start_time": "2026-02-06T10:00:00.000Z",
    "end_time": "2026-02-06T10:15:00.000Z",
    "duration_minutes": 15,
    "user_message_count": 5,
    "assistant_message_count": 10,
    "total_messages": 15,
    "tools_used": ["bash"],
    "project_path": "/Users/test/project",
    "git_branch": "main",
    "input_tokens": 10000,
    "output_tokens": 5000,
    "model": "claude-sonnet-4"
  }]'

  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")

  efficiency=$(echo "$result" | jq -r '.token_efficiency')
  [[ "$efficiency" == "0.5" ]]

  user_msgs=$(echo "$result" | jq -r '.total_user_messages')
  [[ "$user_msgs" == "5" ]]

  asst_msgs=$(echo "$result" | jq -r '.total_assistant_messages')
  [[ "$asst_msgs" == "10" ]]

  avg_per_session=$(echo "$result" | jq -r '.avg_messages_per_session')
  [[ "$avg_per_session" == "15" ]]
}

@test "aggregate-stats.sh: empty array has new fields" {
  result=$(echo '[]' | bash "$AGGREGATE_SCRIPT")

  [[ "$(echo "$result" | jq -r '.project_breakdown | length')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.model_distribution | length')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.duration_percentiles.p50')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.daily_activity | length')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.token_efficiency')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.total_user_messages')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.total_assistant_messages')" == "0" ]]
  [[ "$(echo "$result" | jq -r '.avg_messages_per_session')" == "0" ]]
}

@test "aggregate-stats.sh: handles null project_path" {
  input='[{
    "session_id": "test1",
    "start_time": "2026-02-06T10:00:00.000Z",
    "end_time": "2026-02-06T10:15:00.000Z",
    "duration_minutes": 15,
    "user_message_count": 5,
    "assistant_message_count": 5,
    "total_messages": 10,
    "tools_used": ["bash"],
    "project_path": null,
    "git_branch": null,
    "input_tokens": 5000,
    "output_tokens": 3000,
    "model": "claude-sonnet-4"
  }]'
  
  result=$(echo "$input" | bash "$AGGREGATE_SCRIPT")
  
  # Should not crash and should return valid JSON
  total_sessions=$(echo "$result" | jq -r '.total_sessions')
  [[ "$total_sessions" == "1" ]]
  
  # Projects should be empty object
  projects=$(echo "$result" | jq -r '.projects | length')
  [[ "$projects" == "0" ]]
}
