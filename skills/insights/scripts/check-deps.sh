#!/bin/bash
set -euo pipefail

# check-deps.sh - Verify required dependencies are installed
# Usage: ./check-deps.sh [--quiet]
# Exit code: 0 if all required deps present, 1 otherwise

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly QUIET="${1:-}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Track if all required deps are present
all_required_present=true

# Helper function to check command availability
check_command() {
  local cmd="$1"
  local required="${2:-true}"
  local version_cmd="${3:-}"
  
  if command -v "$cmd" &> /dev/null; then
    local version=""
    if [[ -n "$version_cmd" ]]; then
      version=$($version_cmd 2>/dev/null || echo "unknown")
      version=" (${version})"
    fi
    
    if [[ "$QUIET" != "--quiet" ]]; then
      echo -e "${GREEN}OK${NC}: $cmd${version}"
    fi
  else
    if [[ "$required" == "true" ]]; then
      all_required_present=false
      if [[ "$QUIET" != "--quiet" ]]; then
        echo -e "${RED}MISSING${NC}: $cmd — install with:"
        print_install_instructions "$cmd"
      fi
    else
      if [[ "$QUIET" != "--quiet" ]]; then
        echo -e "${YELLOW}OPTIONAL${NC}: $cmd (not found)"
      fi
    fi
  fi
}

# Helper function to check bash version
check_bash_version() {
  local required_version=4
  local current_version="${BASH_VERSINFO[0]:-0}"
  
  if [[ -z "$current_version" ]] || [[ "$current_version" == "0" ]]; then
    current_version=$(bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 || echo "unknown")
  fi
  
  if [[ "$current_version" != "unknown" ]] && [[ "$current_version" -ge "$required_version" ]]; then
    if [[ "$QUIET" != "--quiet" ]]; then
      local patch="${BASH_VERSINFO[2]:-0}"
      echo -e "${GREEN}OK${NC}: bash ${current_version}.${BASH_VERSINFO[1]:-0}.${patch}"
    fi
  else
    all_required_present=false
    if [[ "$QUIET" != "--quiet" ]]; then
      echo -e "${RED}MISSING${NC}: bash ${required_version}+ (current: ${current_version})"
      echo "  macOS: brew install bash"
      echo "  Linux: apt install bash (or yum install bash)"
    fi
  fi
}

# Helper function to print install instructions
print_install_instructions() {
  local cmd="$1"
  
  case "$cmd" in
    jq)
      echo "  macOS: brew install jq"
      echo "  Linux: apt install jq (or yum install jq)"
      echo "  Windows: choco install jq"
      ;;
    bats)
      echo "  macOS: brew install bats-core"
      echo "  Linux: npm install -g bats"
      echo "  Or: https://github.com/bats-core/bats-core"
      ;;
    *)
      echo "  See: https://github.com/search?q=$cmd"
      ;;
  esac
}

# Main function
main() {
  if [[ "$QUIET" != "--quiet" ]]; then
    echo "Checking dependencies..."
    echo ""
  fi
  
  # Check required dependencies
  check_bash_version
  check_command "jq" "true" "jq --version | cut -d' ' -f2"
  
  # Check optional dependencies
  check_command "bats" "false" "bats --version | head -1"
  
  if [[ "$QUIET" != "--quiet" ]]; then
    echo ""
  fi
  
  # Exit with appropriate code
  if [[ "$all_required_present" == "true" ]]; then
    if [[ "$QUIET" != "--quiet" ]]; then
      echo -e "${GREEN}✓ All required dependencies are installed${NC}"
    fi
    return 0
  else
    if [[ "$QUIET" != "--quiet" ]]; then
      echo -e "${RED}✗ Some required dependencies are missing${NC}"
    fi
    return 1
  fi
}

main "$@"
