# CLI Session Storage Formats

This document describes how each supported AI coding assistant CLI stores session data. This information is used by `collect-sessions.sh` to implement CLI-specific adapters.

---

## Claude Code

**Minimum Version**: 2.1+

**Storage Path**: `~/.claude/projects/<normalized-path>/<sessionID>.jsonl`

**Path Normalization**: Project paths are normalized by replacing `/` with `-`:
- `/Users/user/project` → `-Users-user-project`

**Format**: JSONL (JSON Lines) - one JSON object per line

**Message Types**:
- `user` - User messages
- `assistant` - Assistant messages
- `progress` - Agent progress updates
- `file-history-snapshot` - File history snapshots

**Key Fields**:
```json
{
  "type": "user|assistant|progress|file-history-snapshot",
  "message": {
    "role": "user|assistant",
    "content": "string or array"
  },
  "uuid": "string (message ID)",
  "timestamp": "string (ISO-8601)",
  "sessionId": "string",
  "version": "string (CLI version)",
  "cwd": "string (working directory)",
  "gitBranch": "string (current branch)",
  "thinkingMetadata": {
    "level": "high|medium|low",
    "disabled": "boolean",
    "triggers": ["string"]
  },
  "todos": ["array of todo items"]
}
```

**Filtering Rules**:
- Skip sessions in directories starting with `agent-` (agent sub-sessions)
- Skip sessions with <2 user messages
- Skip sessions with <1 minute duration
- Skip internal facet-extraction sessions (check first 5 messages for "RESPOND WITH ONLY A VALID JSON OBJECT")

**Example Session File**:
```
~/.claude/projects/-Users-user-myproject/abc123-def456.jsonl
```

**Reading Strategy**:
1. List all `.jsonl` files in project directory
2. For each file, read line-by-line (each line is a JSON object)
3. Extract metadata: count messages, calculate duration, collect tools used
4. Filter based on rules above
5. Output session metadata JSON

---

## OpenCode

**Minimum Version**: 1.1+

**Storage Path**: `~/.local/share/opencode/storage/`

**Format**: Hierarchical JSON - separate files for sessions, messages, and parts

**Directory Structure**:
```
~/.local/share/opencode/storage/
├── session/
│   └── <projectID>/
│       └── <sessionID>.json
├── message/
│   └── <sessionID>/
│       ├── <messageID>.json
│       └── <messageID>.json
└── part/
    └── <messageID>/
        └── <partID>.json
```

**Session File Fields**:
```json
{
  "id": "string (session ID)",
  "slug": "string (human-readable name)",
  "projectID": "string",
  "directory": "string (working directory)",
  "title": "string",
  "version": "string (CLI version)",
  "time": {
    "created": "number (Unix timestamp ms)",
    "updated": "number (Unix timestamp ms)",
    "compacting": "number (optional)",
    "archived": "number (optional)"
  },
  "summary": {
    "additions": "number (lines added)",
    "deletions": "number (lines removed)",
    "files": "number (files modified)",
    "diffs": ["array of file diffs (optional)"]
  },
  "share": {
    "url": "string (optional)"
  },
  "permission": "object (optional)",
  "revert": "object (optional)"
}
```

**Message File Fields**:
```json
{
  "id": "string (message ID)",
  "sessionID": "string",
  "role": "user|assistant",
  "content": "string or array",
  "timestamp": "number (Unix timestamp ms)",
  "model": "string (optional)",
  "tokens": {
    "input": "number",
    "output": "number"
  }
}
```

**Filtering Rules**:
- Skip sessions with <2 messages
- Skip sessions with <1 minute duration (time.updated - time.created)

**Reading Strategy**:
1. List all session JSON files in `session/<projectID>/`
2. For each session, read session JSON
3. List message files in `message/<sessionID>/`
4. Count messages, calculate duration from timestamps
5. Extract metadata from session + message files
6. Filter and output session metadata JSON

---

## Codex

**Minimum Version**: 0.87+

**Storage Path**: `~/.codex/sessions/YYYY/MM/DD/`

**Format**: JSONL with date-organized structure

**Directory Structure**:
```
~/.codex/sessions/
├── 2026/
│   ├── 02/
│   │   ├── 01/
│   │   │   ├── rollout-001.jsonl
│   │   │   └── rollout-002.jsonl
│   │   └── 02/
│   │       └── rollout-003.jsonl
└── history.jsonl (session index)
```

**Session File Fields**:
```json
{
  "timestamp": "string (ISO-8601)",
  "type": "session_meta|response_item",
  "payload": {
    "session_id": "string",
    "project_path": "string",
    "git_branch": "string",
    "model": "string",
    "messages": [
      {
        "role": "user|assistant|system",
        "content": "string"
      }
    ],
    "tools_used": ["string"],
    "tokens": {
      "input": "number",
      "output": "number"
    }
  }
}
```

**History File**:
The `history.jsonl` file provides an index of all sessions:
```json
{
  "session_id": "string",
  "date": "string (YYYY-MM-DD)",
  "file_path": "string (relative path to session file)",
  "message_count": "number",
  "duration_minutes": "number"
}
```

**Filtering Rules**:
- Skip sessions with <2 messages
- Skip sessions with <1 minute duration

**Reading Strategy**:
1. Read `history.jsonl` to get session index
2. For each session, read the corresponding JSONL file
3. Parse each line (type: session_meta or response_item)
4. Extract metadata from payload
5. Filter and output session metadata JSON

---

## Adding a New CLI Adapter

To add support for a new CLI:

1. **Research the storage format**:
   - Find where sessions are stored
   - Understand the file format (JSON, JSONL, SQLite, etc.)
   - Identify key fields (session ID, timestamps, messages, etc.)

2. **Add detection logic to `detect-cli.sh`**:
   - Check for CLI-specific environment variables
   - Check for CLI-specific processes
   - Check for CLI-specific directory structure
   - Add scoring logic

3. **Implement adapter function in `collect-sessions.sh`**:
   ```bash
   collect_new_cli() {
     local session_dir="${1:-$HOME/.newcli/sessions}"
      local limit="${2:-0}"
     
     # Read session files
     # Extract metadata
     # Filter sessions
     # Output JSON array
   }
   ```

4. **Add CLI case to main dispatch**:
   ```bash
   case "$CLI_TYPE" in
     claude-code) collect_claude_code "$SESSION_DIR" "$LIMIT" ;;
     opencode) collect_opencode "$SESSION_DIR" "$LIMIT" ;;
     codex) collect_codex "$SESSION_DIR" "$LIMIT" ;;
     new-cli) collect_new_cli "$SESSION_DIR" "$LIMIT" ;;
     *) echo "Unknown CLI: $CLI_TYPE" >&2; exit 1 ;;
   esac
   ```

5. **Create test fixtures**:
   - Add synthetic session data to `tests/fixtures/new-cli/`
   - Follow the CLI's actual format
   - Include edge cases (short sessions, malformed data, etc.)

6. **Add Bats tests**:
   - Test session collection from fixtures
   - Test filtering logic
   - Test JSON output validity

7. **Update documentation**:
   - Add CLI to this file (cli-formats.md)
   - Update SKILL.md compatibility field
   - Update README.md supported CLIs list

---

## Common Patterns

### Session Metadata Extraction

All adapters should extract these fields:
- `session_id` - Unique identifier
- `start_time` - ISO-8601 timestamp
- `end_time` - ISO-8601 timestamp
- `duration_minutes` - Calculated from timestamps
- `user_message_count` - Count of user messages
- `assistant_message_count` - Count of assistant messages
- `total_messages` - Sum of all messages
- `tools_used` - Array of tool names
- `project_path` - Working directory
- `git_branch` - Current git branch (or null)
- `input_tokens` - Total input tokens
- `output_tokens` - Total output tokens
- `model` - Model identifier

### Filtering Logic

All adapters should filter out:
- Sessions with <2 user messages
- Sessions with <1 minute duration
- Agent sub-sessions (if applicable)
- Internal/warmup sessions (if detectable)

### Output Format

All adapters output a JSON array to stdout:
```json
[
  { "session_id": "...", "start_time": "...", ... },
  { "session_id": "...", "start_time": "...", ... }
]
```

Sorted by `start_time` descending (most recent first).
