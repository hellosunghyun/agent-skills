# Analysis Prompts for Insights Skill

This document contains the 8 analysis prompts used to generate insights from session data. Each prompt is executed by the agent with aggregated session statistics and facet data as context.

---

## 1. Project Areas

**Purpose**: Identify what the user works on across their sessions.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and identify project areas.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "areas": [
    {
      "name": "Area name",
      "session_count": N,
      "description": "2-3 sentences about what was worked on"
    }
  ]
}

Include 4-5 areas. Skip internal operations and warmup sessions.
```

**Expected Output Schema**:
```json
{
  "areas": [
    {
      "name": "string",
      "session_count": "number",
      "description": "string"
    }
  ]
}
```

---

## 2. Interaction Style

**Purpose**: Describe how the user interacts with the AI assistant.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and describe the user's interaction style.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "narrative": "2-3 paragraphs analyzing HOW the user interacts with the AI assistant. Use second person 'you'.",
  "key_pattern": "One sentence summary of most distinctive interaction style"
}
```

**Expected Output Schema**:
```json
{
  "narrative": "string",
  "key_pattern": "string"
}
```

---

## 3. What Works

**Purpose**: Highlight impressive workflows and effective usage patterns.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and identify what's working well for this user.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "intro": "1 sentence of context",
  "impressive_workflows": [
    {
      "title": "Short title (3-6 words)",
      "description": "2-3 sentences describing the impressive workflow"
    }
  ]
}

Include 3 impressive workflows.
```

**Expected Output Schema**:
```json
{
  "intro": "string",
  "impressive_workflows": [
    {
      "title": "string",
      "description": "string"
    }
  ]
}
```

---

## 4. Friction Analysis

**Purpose**: Identify pain points and areas where the user encounters difficulties.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and identify friction points for this user.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "intro": "1 sentence summarizing friction patterns",
  "categories": [
    {
      "category": "Concrete category name",
      "description": "1-2 sentences explaining this category",
      "examples": ["Specific example with consequence", "Another example"]
    }
  ]
}

Include 3 friction categories with 2 examples each.
```

**Expected Output Schema**:
```json
{
  "intro": "string",
  "categories": [
    {
      "category": "string",
      "description": "string",
      "examples": ["string"]
    }
  ]
}
```

---

## 5. Suggestions

**Purpose**: Recommend features, usage patterns, and improvements.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and suggest improvements.

Consider CLI-specific features from references/suggestions-by-cli.md.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "claude_md_additions": [
    {
      "title": "Short title",
      "content": "Specific instruction or pattern to add to CLAUDE.md",
      "why": "1 sentence explaining the benefit"
    }
  ],
  "features_to_try": [
    {
      "feature": "Feature name",
      "description": "What it does and why it's relevant",
      "how_to_use": "Concrete usage example"
    }
  ],
  "usage_patterns": [
    {
      "pattern": "Pattern name",
      "description": "What to do differently",
      "example": "Concrete example"
    }
  ]
}

Include 2-3 items in each category.
```

**Expected Output Schema**:
```json
{
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
}
```

---

## 6. On the Horizon

**Purpose**: Identify future opportunities and ambitious workflows.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and identify future opportunities.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "intro": "1 sentence about evolving AI-assisted development",
  "opportunities": [
    {
      "title": "Short title (4-8 words)",
      "whats_possible": "2-3 ambitious sentences about autonomous workflows",
      "how_to_try": "1-2 sentences mentioning relevant tooling",
      "copyable_prompt": "Detailed prompt to try"
    }
  ]
}

Include 3 opportunities. Think BIG - autonomous workflows, parallel agents, iterating against tests.
```

**Expected Output Schema**:
```json
{
  "intro": "string",
  "opportunities": [
    {
      "title": "string",
      "whats_possible": "string",
      "how_to_try": "string",
      "copyable_prompt": "string"
    }
  ]
}
```

---

## 7. Fun Ending

**Purpose**: Find a memorable, human moment from the sessions.

**Max Tokens**: 8192

**Prompt**:
```
Analyze this AI coding assistant usage data and find a memorable moment.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "headline": "A memorable QUALITATIVE moment - something human, funny, or surprising",
  "detail": "Brief context about when/where this happened"
}
```

**Expected Output Schema**:
```json
{
  "headline": "string",
  "detail": "string"
}
```

---

## 8. At a Glance

**Purpose**: Generate an executive summary with 4 key sections.

**Max Tokens**: 8192

**Prompt**:
```
You're writing an "At a Glance" summary for an AI coding assistant usage insights report.

Use this 4-part structure:
1. **What's working** - User's unique style and impactful things they've done
2. **What's hindering you** - AI assistant's faults and user-side friction
3. **Quick wins to try** - Specific features from the detected CLI
4. **Ambitious workflows** - What becomes possible with better models

Keep each section to 2-3 not-too-long sentences.

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "whats_working": "...",
  "whats_hindering": "...",
  "quick_wins": "...",
  "ambitious_workflows": "..."
}
```

**Expected Output Schema**:
```json
{
  "whats_working": "string",
  "whats_hindering": "string",
  "quick_wins": "string",
  "ambitious_workflows": "string"
}
```

---

## Usage

These prompts are executed by the agent in Step 6 of the SKILL.md orchestration flow. The agent should:

1. Load aggregated statistics from `aggregate-stats.sh`
2. Load facet data from previous facet extraction step
3. Execute all 8 prompts (can be parallelized if platform supports it)
4. Combine results into a single insights JSON object
5. Pass to `generate-report.sh` for HTML generation

## Context Provided to Each Prompt

Each prompt receives:
- Aggregated statistics (total sessions, messages, hours, commits, top tools/goals)
- Session summaries (up to 50 brief summaries with outcomes)
- Friction details (up to 20 friction points from sessions)
- User instructions to AI (up to 15 repeated instructions)
- Language distribution
- Satisfaction breakdown
- Success metrics
