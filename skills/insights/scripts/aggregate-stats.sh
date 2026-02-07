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
      message_hours: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      project_breakdown: {},
      model_distribution: {},
      duration_percentiles: {p50: 0, p75: 0, p90: 0, min: 0, max: 0, avg: 0},
      daily_activity: [],
      token_efficiency: 0,
      total_user_messages: 0,
      total_assistant_messages: 0,
      peak_hour: 0,
      session_hours: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
      avg_messages_per_session: 0
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
    
    # Recalculate tool counts properly: count sessions per tool (deduplicate within each session)
    (reduce $sessions[] as $session (
      {};
      . as $counts |
      reduce (($session.tools_used // []) | unique)[] as $tool (
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
    
    # Per-project breakdown: sessions, messages, duration, tokens for each project
    (reduce $sessions[] as $session (
      {};
      if $session.project_path != null then
        .[$session.project_path].sessions = ((.[$session.project_path].sessions // 0) + 1) |
        .[$session.project_path].messages = ((.[$session.project_path].messages // 0) + $session.total_messages) |
        .[$session.project_path].duration_minutes = ((.[$session.project_path].duration_minutes // 0) + $session.duration_minutes) |
        .[$session.project_path].input_tokens = ((.[$session.project_path].input_tokens // 0) + $session.input_tokens) |
        .[$session.project_path].output_tokens = ((.[$session.project_path].output_tokens // 0) + $session.output_tokens)
      else . end
    )) as $project_breakdown |

    # Model distribution: count sessions per model
    (reduce $sessions[] as $session (
      {};
      if $session.model != null then
        .[$session.model] = ((.[$session.model] // 0) + 1)
      else . end
    )) as $model_distribution |

    # Session duration percentiles (p50, p75, p90)
    ($sessions | map(.duration_minutes) | sort) as $sorted_durations |
    ($sorted_durations | length) as $n |
    (if $n > 0 then
      {
        p50: $sorted_durations[(($n * 0.5) | floor)],
        p75: $sorted_durations[(($n * 0.75) | floor)],
        p90: $sorted_durations[(($n * 0.90) | floor)],
        min: $sorted_durations[0],
        max: $sorted_durations[$n - 1],
        avg: (($sorted_durations | add) / $n * 10 | round / 10)
      }
    else
      { p50: 0, p75: 0, p90: 0, min: 0, max: 0, avg: 0 }
    end) as $duration_percentiles |

    # Daily activity trend: messages and sessions per date
    (reduce $sessions[] as $session (
      {};
      ($session.start_time | split("T")[0]) as $date |
      .[$date].sessions = ((.[$date].sessions // 0) + 1) |
      .[$date].messages = ((.[$date].messages // 0) + $session.total_messages) |
      .[$date].duration_minutes = ((.[$date].duration_minutes // 0) + $session.duration_minutes)
    ) | to_entries | sort_by(.key) | map({date: .key} + .value)) as $daily_activity |

    # Token efficiency: output/input ratio
    (if $total_input_tokens > 0 then
      ($total_output_tokens / $total_input_tokens * 100 | round / 100)
    else 0 end) as $token_efficiency |

    # User vs assistant message ratio
    ($sessions | map(.user_message_count // 0) | add // 0) as $total_user_messages |
    ($sessions | map(.assistant_message_count // 0) | add // 0) as $total_assistant_messages |

    # Peak hour (hour with most messages)
    ($message_hours | to_entries | max_by(.value) | .key) as $peak_hour |

    # Session hours (count sessions by hour, not messages)
    (reduce $sessions[] as $session (
      [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
      ($session.start_time | split("T")[1] | split(":")[0] | tonumber) as $hour |
      .[$hour] = (.[$hour] + 1)
    )) as $session_hours |

    # Average messages per session
    (if $total_sessions > 0 then
      ($total_messages / $total_sessions * 10 | round / 10)
    else 0 end) as $avg_messages_per_session |

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
      message_hours: $message_hours,
      project_breakdown: $project_breakdown,
      model_distribution: $model_distribution,
      duration_percentiles: $duration_percentiles,
      daily_activity: $daily_activity,
      token_efficiency: $token_efficiency,
      total_user_messages: $total_user_messages,
      total_assistant_messages: $total_assistant_messages,
      peak_hour: $peak_hour,
      session_hours: $session_hours,
      avg_messages_per_session: $avg_messages_per_session
    }
  end
'
