#!/usr/bin/env bash
# Test helper functions for insights skill tests

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"

setup() {
  # Create temp directory for test isolation
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
}

teardown() {
  # Cleanup temp directory
  if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}
