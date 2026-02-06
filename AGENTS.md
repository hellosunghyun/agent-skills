# Agent Skills Repository Structure & Conventions

This document describes the structure, conventions, and standards for the agent-skills repository.

## Repository Structure

```
agent-skills/
├── README.md                 # Project overview and installation
├── LICENSE                   # MIT license
├── AGENTS.md                 # This file - conventions and structure
├── .gitignore                # Git ignore rules
└── skills/
    ├── insights/             # Example skill: session analysis
    │   ├── SKILL.md          # Skill metadata and documentation
    │   ├── scripts/          # Executable scripts
    │   │   └── templates/    # Script templates
    │   ├── references/       # Supporting documentation
    │   └── tests/
    │       └── fixtures/     # Test data and fixtures
    └── [other-skills]/       # Additional skills follow same pattern
```

## Skill Naming Conventions

- **Directory names**: kebab-case (e.g., `insights`, `code-review`, `test-generator`)
- **Script names**: kebab-case with language extension (e.g., `analyze-session.sh`, `generate-report.py`)
- **File names**: kebab-case (e.g., `SKILL.md`, `test-fixtures.json`)

## SKILL.md Format

Each skill must include a `SKILL.md` file at the root of the skill directory. This file documents:

```markdown
# Skill Name

## Description
Brief description of what the skill does.

## Usage
How to invoke the skill and what parameters it accepts.

## Scripts
List of executable scripts and their purposes.

## Examples
Usage examples and expected outputs.

## Requirements
Dependencies, environment variables, or system requirements.
```

## Script Conventions

All scripts must follow these conventions:

### Bash Scripts
- Start with `#!/bin/bash`
- Include `set -euo pipefail` for error handling
- Use POSIX-compatible syntax (avoid bashisms)
- Include comments explaining complex logic
- Exit with code 0 on success, non-zero on failure
- Accept parameters via command-line arguments or environment variables

Example:
```bash
#!/bin/bash
set -euo pipefail

# Script description
# Usage: ./script.sh [arg1] [arg2]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

main() {
  local arg1="${1:-}"
  local arg2="${2:-}"
  
  if [[ -z "$arg1" ]]; then
    echo "Error: arg1 is required" >&2
    return 1
  fi
  
  # Implementation
  echo "Processing: $arg1"
}

main "$@"
```

### Python Scripts
- Use Python 3.8+
- Include shebang: `#!/usr/bin/env python3`
- Use type hints where practical
- Include docstrings for functions and modules
- Handle errors gracefully with informative messages
- Exit with code 0 on success, non-zero on failure

Example:
```python
#!/usr/bin/env python3
"""Script description and usage."""

import sys
from pathlib import Path

def main(arg1: str, arg2: str = "") -> int:
    """Main function.
    
    Args:
        arg1: First argument (required)
        arg2: Second argument (optional)
    
    Returns:
        Exit code (0 for success, non-zero for failure)
    """
    if not arg1:
        print("Error: arg1 is required", file=sys.stderr)
        return 1
    
    print(f"Processing: {arg1}")
    return 0

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
```

## Directory Structure for Skills

Each skill should follow this structure:

```
skills/[skill-name]/
├── SKILL.md                  # Skill documentation
├── scripts/                  # Executable scripts
│   ├── main-script.sh        # Primary script
│   ├── helper-script.sh      # Helper scripts
│   └── templates/            # Script templates or boilerplate
├── references/               # Supporting documentation
│   ├── api-reference.md      # API or command reference
│   └── examples.md           # Usage examples
└── tests/
    ├── fixtures/             # Test data files
    │   ├── sample-input.json
    │   └── expected-output.json
    └── test-script.sh        # Test runner
```

## Testing

Each skill should include tests in the `tests/` directory:

- **fixtures/**: Sample input data and expected outputs
- **test-script.sh**: Automated test runner
- Tests should be runnable with `bash tests/test-script.sh`
- Tests should exit with code 0 on success, non-zero on failure

## Documentation Standards

- Use Markdown for all documentation
- Include examples with expected output
- Document all parameters and options
- Explain error conditions and how to handle them
- Link to external resources where relevant

## Version Control

- Commit messages should be descriptive and follow conventional commits
- Use atomic commits (one logical change per commit)
- Include tests with new features
- Update documentation with code changes

## License

All skills in this repository are licensed under the MIT License. Include a LICENSE file reference in each skill's documentation.

## References

- [agentskills.io Specification](https://agentskills.io)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [POSIX Shell](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
