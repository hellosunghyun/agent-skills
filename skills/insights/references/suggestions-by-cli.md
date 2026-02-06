# CLI-Specific Feature Suggestions

This document provides CLI-specific features and capabilities that should be referenced in the "suggestions" analysis prompt. The agent should tailor suggestions based on which CLI was detected.

---

## Claude Code

**Detected CLI**: `claude-code`

### MCP Servers
Model Context Protocol servers extend Claude Code with custom tools and data sources.

**Features**:
- Connect to databases, APIs, and external services
- Add custom tools for specialized workflows
- Access real-time data during conversations

**How to Use**:
Add to `~/.claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["/path/to/server.js"]
    }
  }
}
```

**When to Suggest**: User frequently needs external data, API access, or specialized tools

---

### Custom Skills
Reusable instruction sets that extend Claude's capabilities.

**Features**:
- Package domain expertise as skills
- Share skills across projects
- Progressive disclosure (load details on-demand)

**How to Use**:
Create `SKILL.md` in `.claude/skills/` or `~/.claude/skills/`:
```markdown
---
name: my-skill
description: What this skill does
---

# My Skill
Instructions for Claude...
```

**When to Suggest**: User has repeated workflows, domain-specific patterns, or reusable instructions

---

### Hooks
Intercept and modify Claude's behavior at key points.

**Features**:
- Pre-process user messages
- Post-process assistant responses
- Inject context automatically
- Custom verification steps

**How to Use**:
Create hooks in `.claude/hooks/`:
- `pre-message.js` - Before Claude sees user message
- `post-response.js` - After Claude generates response
- `pre-tool.js` - Before tool execution
- `post-tool.js` - After tool execution

**When to Suggest**: User needs automatic context injection, response filtering, or custom verification

---

### Headless Mode
Run Claude Code from command line without GUI.

**Features**:
- Automate workflows with scripts
- CI/CD integration
- Batch processing

**How to Use**:
```bash
claude --headless "prompt here"
claude --headless --file input.txt
```

**When to Suggest**: User has repetitive tasks, wants CI/CD integration, or needs automation

---

### Task Agents
Spawn sub-agents for parallel or specialized work.

**Features**:
- Delegate subtasks to specialized agents
- Run multiple agents in parallel
- Isolate context for focused work

**How to Use**:
```
/task "Implement feature X" --agent architect
/task "Write tests" --agent tester --background
```

**When to Suggest**: User has complex multi-step workflows, parallel tasks, or needs specialized expertise

---

### /compact Command
Compress conversation history to save context.

**Features**:
- Summarize long conversations
- Preserve key decisions and context
- Continue with fresh context window

**How to Use**:
```
/compact
```

**When to Suggest**: User has very long sessions, hitting context limits, or needs to preserve key decisions

---

## OpenCode

**Detected CLI**: `opencode`

### Custom Commands
Define reusable commands in configuration.

**Features**:
- Create shortcuts for common workflows
- Parameterized commands
- Chain multiple operations

**How to Use**:
Add to `~/.config/opencode/config.json`:
```json
{
  "commands": {
    "deploy": {
      "template": "Deploy to {{environment}} with {{version}}",
      "agent": "devops"
    }
  }
}
```

**When to Suggest**: User has repeated command patterns or multi-step workflows

---

### MCP Integration
OpenCode supports Model Context Protocol for extensibility.

**Features**:
- Add custom tools via MCP servers
- Access external data sources
- Extend with community plugins

**How to Use**:
Configure MCP servers in `~/.config/opencode/config.json`:
```json
{
  "mcp": {
    "servers": {
      "server-name": {
        "command": "node",
        "args": ["/path/to/server.js"]
      }
    }
  }
}
```

**When to Suggest**: User needs external integrations or specialized tools

---

### Skill System
OpenCode auto-discovers skills from multiple locations.

**Features**:
- Skills from `.claude/skills/` and `.agents/skills/`
- URL-based skills (load from remote)
- Config-based skill paths

**How to Use**:
Add skills to:
- Project: `.agents/skills/`
- Global: `~/.config/opencode/skills/`
- Config: Add to `config.skills.paths`

**When to Suggest**: User has domain expertise to package or reusable workflows

---

### Config-Based Workflows
Customize OpenCode behavior via configuration.

**Features**:
- Set default models per task type
- Configure agent behavior
- Define custom skill paths

**How to Use**:
Edit `~/.config/opencode/config.json`:
```json
{
  "skills": {
    "paths": ["/custom/skills/path"],
    "urls": ["https://example.com/skill.md"]
  },
  "agents": {
    "default": "architect"
  }
}
```

**When to Suggest**: User wants consistent behavior, custom defaults, or team-wide configuration

---

## Codex

**Detected CLI**: `codex`

### Skills System
Codex has a mature skills system with `.system` skills.

**Features**:
- System skills (built-in, always available)
- User skills (custom, per-user)
- Project skills (per-project)

**How to Use**:
Add skills to:
- System: `~/.codex/skills/.system/`
- User: `~/.codex/skills/`
- Project: `.codex/skills/`

**When to Suggest**: User has repeated patterns or domain-specific workflows

---

### Progressive Disclosure
Codex emphasizes progressive disclosure in skills.

**Features**:
- Load minimal context upfront
- Reference detailed docs on-demand
- Keep context window efficient

**How to Use**:
Structure skills with:
- Brief overview in main SKILL.md
- Detailed references in `references/`
- Examples in `examples/`

**When to Suggest**: User has complex domains with extensive documentation

---

### .system Skills
Built-in skills that provide core functionality.

**Features**:
- `skill-creator` - Create new skills
- `skill-installer` - Install skills from repos
- Always available, no installation needed

**How to Use**:
```
/skill-creator "Create a skill for X"
/skill-installer "Install skill from github.com/user/repo"
```

**When to Suggest**: User wants to create custom skills or install community skills

---

## General Suggestions (All CLIs)

### CLAUDE.md / AGENTS.md
Add persistent instructions to guide the AI.

**Features**:
- Project-specific conventions
- Coding standards
- Workflow preferences

**How to Use**:
Create `CLAUDE.md` or `AGENTS.md` in project root with instructions.

**When to Suggest**: User repeatedly gives same instructions or has project-specific patterns

---

### Session Organization
Organize work into focused sessions.

**Features**:
- One session per feature/bug
- Clear session goals
- Easier to review and learn from

**When to Suggest**: User has long, unfocused sessions or mixes multiple tasks

---

### Iterative Refinement
Break large tasks into smaller iterations.

**Features**:
- Get working version quickly
- Iterate based on feedback
- Easier to debug and verify

**When to Suggest**: User attempts large changes in one go or gets stuck on complex tasks

---

## Usage in Suggestions Prompt

The "suggestions" analysis prompt should:

1. Detect which CLI is being used (from context)
2. Reference this file for CLI-specific features
3. Suggest 2-3 features that match the user's patterns
4. Provide concrete usage examples
5. Explain why each feature is relevant to this specific user

Example suggestion structure:
```json
{
  "features_to_try": [
    {
      "feature": "MCP Servers (Claude Code)",
      "description": "You frequently need to query databases during development. MCP servers can connect Claude directly to your database.",
      "how_to_use": "Add a database MCP server to ~/.claude/claude_desktop_config.json to query your DB without leaving the conversation."
    }
  ]
}
```
