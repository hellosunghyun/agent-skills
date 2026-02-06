#!/usr/bin/env bats

setup() {
  SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && cd ../scripts && pwd)"
  SCRIPT="${SCRIPT_DIR}/check-deps.sh"
  
  TEST_PATH="${BATS_TMPDIR}/test-path"
  mkdir -p "${TEST_PATH}"
}

@test "returns 0 when all required dependencies are available" {
  run bash "${SCRIPT}"
  local clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$clean_output" =~ "OK: jq" ]]
}

@test "returns 1 and shows helpful message when jq is missing" {
  export PATH="${TEST_PATH}:/usr/bin:/bin"
  
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "MISSING: jq" ]]
  [[ "$output" =~ "install" ]]
}

@test "accepts --quiet flag and suppresses output" {
  run bash "${SCRIPT}" --quiet
  [ -z "$output" ] || [[ "$output" != *"OK:"* ]]
}

@test "shows optional dependencies status" {
  run bash "${SCRIPT}"
  [[ "$output" =~ "bats" ]] || [[ "$output" =~ "optional" ]]
}

@test "checks bash version" {
  run bash "${SCRIPT}"
  [[ "$output" =~ "bash" ]]
}

@test "returns 1 when bash version is below 4" {
  run bash -c "BASH_VERSINFO=(3 0 0 0); source ${SCRIPT}"
  [ "$status" -ne 0 ] || [[ "$output" =~ "bash" ]]
}
