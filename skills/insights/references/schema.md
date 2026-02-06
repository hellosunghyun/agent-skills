# JSON Schemas for Insights Skill

This document defines the JSON schemas for all data contracts in the insights skill. These schemas serve as the interface between shell scripts, the agent, and the HTML template.

---

## 1. Session Metadata

**Source**: Output of `collect-sessions.sh`

**Description**: Metadata extracted from a single session file.

**Schema**:
```json
{
  "session_id": "string (unique identifier)",
  "start_time": "string (ISO-8601 timestamp)",
  "end_time": "string (ISO-8601 timestamp)",
  "duration_minutes": "number",
  "user_message_count": "number",
  "assistant_message_count": "number",
  "total_messages": "number",
  "tools_used": ["string (tool names)"],
  "project_path": "string (absolute path)",
  "git_branch": "string (branch name or null)",
  "input_tokens": "number",
  "output_tokens": "number",
  "model": "string (model identifier)"
}
```

**Example**:
```json
{
  "session_id": "abc123",
  "start_time": "2026-02-06T10:00:00Z",
  "end_time": "2026-02-06T10:15:00Z",
  "duration_minutes": 15,
  "user_message_count": 5,
  "assistant_message_count": 5,
  "total_messages": 10,
  "tools_used": ["bash", "edit", "read"],
  "project_path": "/Users/user/project",
  "git_branch": "main",
  "input_tokens": 5000,
  "output_tokens": 3000,
  "model": "claude-sonnet-4"
}
```

---

## 2. Aggregated Stats

**Source**: Output of `aggregate-stats.sh`

**Description**: Statistics aggregated across all sessions.

**Schema**:
```json
{
  "total_sessions": "number",
  "date_range": {
    "start": "string (YYYY-MM-DD)",
    "end": "string (YYYY-MM-DD)"
  },
  "total_messages": "number",
  "total_duration_hours": "number (decimal)",
  "total_input_tokens": "number",
  "total_output_tokens": "number",
  "tool_counts": {
    "tool_name": "number (count)"
  },
  "languages": {
    "language_name": "number (count)"
  },
  "git_commits": "number",
  "git_pushes": "number",
  "projects": {
    "project_path": "number (session count)"
  },
  "days_active": "number",
  "messages_per_day": "number (decimal)",
  "message_hours": ["number (24 elements, one per hour)"]
}
```

**Example**:
```json
{
  "total_sessions": 42,
  "date_range": {
    "start": "2026-01-01",
    "end": "2026-02-06"
  },
  "total_messages": 500,
  "total_duration_hours": 12.5,
  "total_input_tokens": 250000,
  "total_output_tokens": 150000,
  "tool_counts": {
    "bash": 120,
    "edit": 80,
    "read": 200
  },
  "languages": {
    "TypeScript": 150,
    "Python": 50
  },
  "git_commits": 25,
  "git_pushes": 10,
  "projects": {
    "/Users/user/project1": 30,
    "/Users/user/project2": 12
  },
  "days_active": 15,
  "messages_per_day": 33.3,
  "message_hours": [0,0,0,0,0,0,0,0,5,10,15,20,25,30,25,20,15,10,5,0,0,0,0,0]
}
```

---

## 3. Facet Data

**Source**: Agent-executed facet extraction (per session)

**Description**: Qualitative assessment of a single session.

**Schema**:
```json
{
  "session_id": "string",
  "brief_summary": "string (3-5 sentences)",
  "goal_categories": {
    "debug_investigate": "number (0 or 1)",
    "implement_feature": "number (0 or 1)",
    "fix_bug": "number (0 or 1)",
    "write_script_tool": "number (0 or 1)",
    "refactor_code": "number (0 or 1)",
    "configure_system": "number (0 or 1)",
    "create_pr_commit": "number (0 or 1)",
    "analyze_data": "number (0 or 1)",
    "understand_codebase": "number (0 or 1)",
    "write_tests": "number (0 or 1)",
    "write_docs": "number (0 or 1)",
    "deploy_infra": "number (0 or 1)",
    "warmup_minimal": "number (0 or 1)"
  },
  "outcome": "string (not_achieved|partially_achieved|mostly_achieved|fully_achieved|unclear_from_transcript)",
  "user_satisfaction_counts": {
    "frustrated": "number",
    "dissatisfied": "number",
    "likely_satisfied": "number",
    "satisfied": "number",
    "happy": "number",
    "unsure": "number"
  },
  "claude_helpfulness": "string (not_helpful|somewhat_helpful|helpful|very_helpful|unclear)",
  "session_type": "string (exploration|implementation|debugging|refactoring|documentation|mixed)",
  "friction_counts": {
    "misunderstood_request": "number",
    "wrong_approach": "number",
    "buggy_code": "number",
    "user_rejected_action": "number",
    "excessive_changes": "number"
  },
  "friction_detail": "string (or null)",
  "primary_success": "string (completed_feature|fixed_bug|improved_code|learned_something|made_progress|none)",
  "user_instructions_to_claude": ["string (repeated instructions)"]
}
```

---

## 4. Insights Data

**Source**: Combined output of all 8 analysis prompts

**Description**: Complete insights report data.

**Schema**:
```json
{
  "project_areas": {
    "areas": [
      {
        "name": "string",
        "session_count": "number",
        "description": "string"
      }
    ]
  },
  "interaction_style": {
    "narrative": "string",
    "key_pattern": "string"
  },
  "what_works": {
    "intro": "string",
    "impressive_workflows": [
      {
        "title": "string",
        "description": "string"
      }
    ]
  },
  "friction_analysis": {
    "intro": "string",
    "categories": [
      {
        "category": "string",
        "description": "string",
        "examples": ["string"]
      }
    ]
  },
  "suggestions": {
    "claude_md_additions": [
      {
        "title": "string",
        "content": "string",
        "why": "string"
      }
    ],
    "features_to_try": [
      {
        "feature": "string",
        "description": "string",
        "how_to_use": "string"
      }
    ],
    "usage_patterns": [
      {
        "pattern": "string",
        "description": "string",
        "example": "string"
      }
    ]
  },
  "on_the_horizon": {
    "intro": "string",
    "opportunities": [
      {
        "title": "string",
        "whats_possible": "string",
        "how_to_try": "string",
        "copyable_prompt": "string"
      }
    ]
  },
  "fun_ending": {
    "headline": "string",
    "detail": "string"
  },
  "at_a_glance": {
    "whats_working": "string",
    "whats_hindering": "string",
    "quick_wins": "string",
    "ambitious_workflows": "string"
  }
}
```

---

## Data Flow

```
Session Files
    ↓
collect-sessions.sh → [Session Metadata] (array)
    ↓
aggregate-stats.sh → [Aggregated Stats] (object)
    ↓
Agent Facet Extraction → [Facet Data] (per session)
    ↓
Agent Analysis Prompts → [Insights Data] (object)
    ↓
generate-report.sh → HTML Report
```

## Usage in Scripts

### collect-sessions.sh
Outputs JSON array of Session Metadata objects to stdout.

### aggregate-stats.sh
Reads Session Metadata array from stdin, outputs Aggregated Stats object to stdout.

### generate-report.sh
Reads Insights Data from stdin, reads Aggregated Stats from `--stats` file argument, outputs HTML file path to stdout.

## Usage in HTML Template

The HTML template receives two JSON blobs via placeholder injection:
- `{{STATS_JSON}}` → Aggregated Stats object
- `{{INSIGHTS_JSON}}` → Insights Data object

Client-side JavaScript in the template parses these and renders the report sections.
