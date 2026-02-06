#!/usr/bin/env bats

# Test suite for detect-cli.sh

setup() {
  # Path to the script under test
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/detect-cli.sh"
  
  # Create temporary test directories
  export TEST_TMPDIR="${BATS_TMPDIR}/detect-cli-test-$$"
  mkdir -p "${TEST_TMPDIR}"
  
  # Save original HOME and environment variables
  export ORIGINAL_HOME="${HOME}"
  export ORIGINAL_CLAUDE_CODE="${CLAUDE_CODE:-}"
  export ORIGINAL_OPENCODE_SESSION="${OPENCODE_SESSION:-}"
  export ORIGINAL_OPENCODE_HOME="${OPENCODE_HOME:-}"
  export ORIGINAL_CODEX_SESSION="${CODEX_SESSION:-}"
  export ORIGINAL_CODEX_HOME="${CODEX_HOME:-}"
  
  # Unset CLI environment variables for clean tests
  unset CLAUDE_CODE
  unset OPENCODE_SESSION
  unset OPENCODE_HOME
  unset CODEX_SESSION
  unset CODEX_HOME
}

teardown() {
  # Restore original HOME
  export HOME="${ORIGINAL_HOME}"
  
  # Restore original environment variables
  [[ -n "${ORIGINAL_CLAUDE_CODE}" ]] && export CLAUDE_CODE="${ORIGINAL_CLAUDE_CODE}" || unset CLAUDE_CODE
  [[ -n "${ORIGINAL_OPENCODE_SESSION}" ]] && export OPENCODE_SESSION="${ORIGINAL_OPENCODE_SESSION}" || unset OPENCODE_SESSION
  [[ -n "${ORIGINAL_OPENCODE_HOME}" ]] && export OPENCODE_HOME="${ORIGINAL_OPENCODE_HOME}" || unset OPENCODE_HOME
  [[ -n "${ORIGINAL_CODEX_SESSION}" ]] && export CODEX_SESSION="${ORIGINAL_CODEX_SESSION}" || unset CODEX_SESSION
  [[ -n "${ORIGINAL_CODEX_HOME}" ]] && export CODEX_HOME="${ORIGINAL_CODEX_HOME}" || unset CODEX_HOME
  
  # Clean up test directories
  rm -rf "${TEST_TMPDIR}"
}

@test "detects Claude Code when ~/.claude/projects/ exists" {
  # Setup: Create Claude Code directory structure
  export HOME="${TEST_TMPDIR}"
  mkdir -p "${HOME}/.claude/projects"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code" ]
}

@test "detects OpenCode when ~/.local/share/opencode/storage/ exists" {
  # Setup: Create OpenCode directory structure
  export HOME="${TEST_TMPDIR}"
  mkdir -p "${HOME}/.local/share/opencode/storage"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 0 ]
  [ "$output" = "opencode" ]
}

@test "detects Codex when ~/.codex/sessions/ exists" {
  # Setup: Create Codex directory structure
  export HOME="${TEST_TMPDIR}"
  mkdir -p "${HOME}/.codex/sessions"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 0 ]
  [ "$output" = "codex" ]
}

@test "returns 'unknown' with exit code 1 for unrecognized environment" {
  # Setup: Empty HOME with no CLI directories
  export HOME="${TEST_TMPDIR}"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 1 ]
  [ "$output" = "unknown" ]
}

@test "respects --cli <name> override argument" {
  # Setup: Empty HOME, but override with flag
  export HOME="${TEST_TMPDIR}"
  
  run "${SCRIPT}" --cli opencode
  
  [ "$status" -eq 0 ]
  [ "$output" = "opencode" ]
}

@test "detects Claude Code via CLAUDE_CODE environment variable" {
  # Setup: Set environment variable
  export HOME="${TEST_TMPDIR}"
  export CLAUDE_CODE="1"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code" ]
  
  unset CLAUDE_CODE
}

@test "detects OpenCode via OPENCODE_SESSION environment variable" {
  # Setup: Set environment variable
  export HOME="${TEST_TMPDIR}"
  export OPENCODE_SESSION="test-session"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 0 ]
  [ "$output" = "opencode" ]
  
  unset OPENCODE_SESSION
}

@test "prioritizes higher-scored CLI when multiple exist" {
  # Setup: Create both Claude Code and Codex directories
  # Claude Code should win (env var = 3 points vs directory = 1 point)
  export HOME="${TEST_TMPDIR}"
  mkdir -p "${HOME}/.codex/sessions"
  export CLAUDE_CODE="1"
  
  run "${SCRIPT}"
  
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code" ]
  
  unset CLAUDE_CODE
}
