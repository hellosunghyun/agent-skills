#!/usr/bin/env bash
set -euo pipefail

# aggregate-stats.sh - Aggregate session metadata into statistics
# Input: JSON array of session metadata (from stdin)
# Output: JSON object with aggregated statistics (to stdout)
# Usage: cat sessions.json | ./aggregate-stats.sh

# Read JSON array from stdin and aggregate statistics
jq -s '
  # Flatten input (in case of nested arrays from -s flag)
  . | if length == 1 and (.[0] | type) == "array" then .[0] else . end |
  
  # Store sessions array
  . as $sessions |
  
  # Handle empty array case
  if ($sessions | length) == 0 then
    {
      total_sessions: 0,
      date_range: {start: null, end: null},
      total_messages: 0,
      total_duration_hours: 0,
      total_input_tokens: 0,
      total_output_tokens: 0,
      tool_counts: {},
      languages: {},
      git_commits: 0,
      git_pushes: 0,
      projects: {},
      days_active: 0,
      messages_per_day: 0,
      message_hours: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    }
  else
    # Total sessions
    ($sessions | length) as $total_sessions |
    
    # Date range (extract YYYY-MM-DD from ISO timestamps)
    ($sessions | map(.start_time | split("T")[0]) | min) as $start_date |
    ($sessions | map(.end_time | split("T")[0]) | max) as $end_date |
    
    # Total messages
    ($sessions | map(.total_messages) | add // 0) as $total_messages |
    
    # Total duration (minutes to hours, rounded to 2 decimal places)
    (($sessions | map(.duration_minutes) | add // 0) / 60 * 100 | round / 100) as $total_duration_hours |
    
    # Total tokens
    ($sessions | map(.input_tokens) | add // 0) as $total_input_tokens |
    ($sessions | map(.output_tokens) | add // 0) as $total_output_tokens |
    
    # Tool counts (count sessions per tool, not individual tool occurrences)
    # For each tool, count how many sessions used it
    ($sessions | 
      map(.tools_used // []) | 
      flatten | 
      group_by(.) | 
      map({
        tool: .[0],
        count: (. | map(.) | length)
      }) |
      # Count unique sessions per tool
      # Actually, we need to count sessions, not tool occurrences
      # Let me recalculate: for each unique tool, count in how many sessions it appears
      {}
    ) as $temp_tool_counts |
    
    # Recalculate tool counts properly: count sessions per tool
    (reduce $sessions[] as $session (
      {};
      . as $counts |
      reduce ($session.tools_used // [])[] as $tool (
        $counts;
        .[$tool] = ((.[$tool] // 0) + 1)
      )
    )) as $tool_counts |
    
    # Projects (count sessions per project_path, excluding nulls)
    (reduce $sessions[] as $session (
      {};
      if $session.project_path != null then
        .[$session.project_path] = ((.[$session.project_path] // 0) + 1)
      else
        .
      end
    )) as $projects |
    
    # Days active (unique dates from start_time)
    ($sessions | map(.start_time | split("T")[0]) | unique | length) as $days_active |
    
    # Messages per day (rounded to 1 decimal place)
    (if $days_active > 0 then
      ($total_messages / $days_active * 10 | round / 10)
    else
      0
    end) as $messages_per_day |
    
    # Message hours (24-element array, count messages by hour of start_time)
    (reduce $sessions[] as $session (
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
      . as $hours |
      ($session.start_time | 
        # Extract hour from ISO timestamp (format: YYYY-MM-DDTHH:MM:SS.sssZ)
        split("T")[1] | split(":")[0] | tonumber
      ) as $hour |
      $hours | .[$hour] = (.[$hour] + $session.total_messages)
    )) as $message_hours |
    
    # Output aggregated stats
    {
      total_sessions: $total_sessions,
      date_range: {
        start: $start_date,
        end: $end_date
      },
      total_messages: $total_messages,
      total_duration_hours: $total_duration_hours,
      total_input_tokens: $total_input_tokens,
      total_output_tokens: $total_output_tokens,
      tool_counts: $tool_counts,
      languages: {},
      git_commits: 0,
      git_pushes: 0,
      projects: $projects,
      days_active: $days_active,
      messages_per_day: $messages_per_day,
      message_hours: $message_hours
    }
  end
'
