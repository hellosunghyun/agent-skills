# agent-skills

A collection of agent skills for AI coding assistants. This repository provides reusable, composable skills that extend the capabilities of Claude Code, OpenCode, and other AI development tools.

## Overview

Agent skills are modular, self-contained tools that AI assistants can invoke to perform specialized tasks. This collection includes skills for code analysis, session insights, report generation, and more.

## Installation

Install skills from this collection using the agent skills CLI:

```bash
npx skills add hellosunghyun/agent-skills
```

Or install a specific skill:

```bash
npx skills add hellosunghyun/agent-skills/insights
```

## Available Skills

### insights
Analyzes AI coding assistant sessions and generates actionable insights. Auto-detects Claude Code, OpenCode, and Codex sessions, extracts command patterns, and produces HTML reports with statistics and recommendations.

**Features:**
- Session auto-detection
- Command pattern analysis
- HTML report generation
- Statistical summaries

## Contributing

We welcome contributions! To add a new skill:

1. Create a new directory under `skills/` with your skill name (kebab-case)
2. Add a `SKILL.md` file documenting the skill
3. Implement skill scripts in `scripts/` subdirectory
4. Add tests in `tests/` subdirectory
5. Submit a pull request

For detailed conventions and requirements, see [AGENTS.md](./AGENTS.md).

## Skill Format

All skills follow the [agentskills.io specification](https://agentskills.io). Each skill includes:

- `SKILL.md` - Skill documentation and metadata
- `scripts/` - Executable scripts (bash, Python, etc.)
- `tests/` - Test fixtures and validation
- `references/` - Supporting documentation

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Resources

- [agentskills.io](https://agentskills.io) - Official skill specification
- [Skill Authoring Guide](./AGENTS.md) - How to create skills
- [Examples](./skills/) - Reference implementations
