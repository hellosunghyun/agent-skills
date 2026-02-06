# Facet Extraction Prompts

This document contains prompts for extracting structured "facets" from individual sessions. Facets are qualitative assessments that capture what the user was trying to do, how satisfied they were, and what friction they encountered.

---

## Session Facet Extraction

**Purpose**: Extract structured metadata from a single session transcript.

**Prompt**:
```
Analyze this AI coding assistant session and extract structured facets.

CRITICAL GUIDELINES:
1. **goal_categories**: Count ONLY what the USER explicitly asked for.
   - DO NOT count the AI's autonomous codebase exploration
   - ONLY count when user says "can you...", "please...", "I need...", "let's..."

2. **user_satisfaction_counts**: Base ONLY on explicit user signals.
   - "Yay!", "great!", "perfect!" → happy
   - "thanks", "looks good", "that works" → satisfied
   - "ok, now let's..." (continuing without complaint) → likely_satisfied
   - "that's not right", "try again" → dissatisfied
   - "this is broken", "I give up" → frustrated

3. **friction_counts**: Be specific about what went wrong.
   - misunderstood_request: AI interpreted incorrectly
   - wrong_approach: Right goal, wrong solution method
   - buggy_code: Code didn't work correctly
   - user_rejected_action: User said no/stop to a tool call
   - excessive_changes: Over-engineered or changed too much

4. If very short or just warmup, use warmup_minimal for goal_category

SESSION:
[session transcript here]

RESPOND WITH ONLY A VALID JSON OBJECT:
{
  "brief_summary": "3-5 sentence summary of what happened",
  "goal_categories": {
    "debug_investigate": 0,
    "implement_feature": 0,
    "fix_bug": 0,
    "write_script_tool": 0,
    "refactor_code": 0,
    "configure_system": 0,
    "create_pr_commit": 0,
    "analyze_data": 0,
    "understand_codebase": 0,
    "write_tests": 0,
    "write_docs": 0,
    "deploy_infra": 0,
    "warmup_minimal": 0
  },
  "outcome": "not_achieved|partially_achieved|mostly_achieved|fully_achieved|unclear_from_transcript",
  "user_satisfaction_counts": {
    "frustrated": 0,
    "dissatisfied": 0,
    "likely_satisfied": 0,
    "satisfied": 0,
    "happy": 0,
    "unsure": 0
  },
  "claude_helpfulness": "not_helpful|somewhat_helpful|helpful|very_helpful|unclear",
  "session_type": "exploration|implementation|debugging|refactoring|documentation|mixed",
  "friction_counts": {
    "misunderstood_request": 0,
    "wrong_approach": 0,
    "buggy_code": 0,
    "user_rejected_action": 0,
    "excessive_changes": 0
  },
  "friction_detail": "Specific description of main friction point, if any",
  "primary_success": "completed_feature|fixed_bug|improved_code|learned_something|made_progress|none",
  "user_instructions_to_claude": ["Any repeated instructions or corrections the user gave"]
}
```

---

## Session Summary

**Purpose**: Generate a concise summary of a session transcript chunk.

**Prompt**:
```
Summarize this portion of an AI coding assistant session transcript. Focus on:
1. What the user asked for
2. What the AI did (tools used, files modified)
3. Any friction or issues
4. The outcome

Keep it concise - 3-5 sentences. Preserve specific details like file names, error messages, and user feedback.

TRANSCRIPT CHUNK:
[transcript here]
```

---

## Enums and Categories

### Goal Categories
```
debug_investigate: "Debug/Investigate"
implement_feature: "Implement Feature"
fix_bug: "Fix Bug"
write_script_tool: "Write Script/Tool"
refactor_code: "Refactor Code"
configure_system: "Configure System"
create_pr_commit: "Create PR/Commit"
analyze_data: "Analyze Data"
understand_codebase: "Understand Codebase"
write_tests: "Write Tests"
write_docs: "Write Docs"
deploy_infra: "Deploy/Infra"
warmup_minimal: "Cache Warmup"
```

### Satisfaction Levels
```
frustrated: User expressed frustration or gave up
dissatisfied: User indicated the result wasn't right
likely_satisfied: User continued without complaint
satisfied: User explicitly said it works/looks good
happy: User expressed enthusiasm (yay!, great!, perfect!)
unsure: Cannot determine from transcript
```

### Outcome Levels
```
not_achieved: Goal was not accomplished
partially_achieved: Some progress but incomplete
mostly_achieved: Nearly complete with minor issues
fully_achieved: Goal fully accomplished
unclear_from_transcript: Cannot determine outcome
```

### Helpfulness Levels
```
not_helpful: AI did not help or made things worse
somewhat_helpful: AI provided some value but with issues
helpful: AI successfully helped achieve the goal
very_helpful: AI exceeded expectations
unclear: Cannot determine from transcript
```

### Session Types
```
exploration: Understanding codebase, investigating issues
implementation: Building new features or functionality
debugging: Fixing errors or unexpected behavior
refactoring: Improving existing code structure
documentation: Writing docs, comments, or explanations
mixed: Multiple types in one session
```

### Friction Types
```
misunderstood_request: AI interpreted user's request incorrectly
wrong_approach: AI chose wrong solution method for the goal
buggy_code: AI generated code that didn't work correctly
user_rejected_action: User said no/stop to an AI action
excessive_changes: AI over-engineered or changed too much
```

### Success Types
```
completed_feature: Finished implementing a new feature
fixed_bug: Successfully resolved a bug or error
improved_code: Refactored or enhanced existing code
learned_something: Gained understanding of codebase/concept
made_progress: Moved forward on a larger goal
none: No clear success in this session
```

---

## Usage

Facet extraction is performed in Step 5 of the SKILL.md orchestration flow:

1. Agent loads up to 20 sessions (most recent first)
2. For each session, agent runs the facet extraction prompt
3. Results are cached to avoid re-analysis on subsequent runs
4. Facets are used as input to the 8 analysis prompts

## Caching

Facets should be cached at:
```
~/.agent-insights/cache/facets/<session-id>.json
```

Cache hit: Reuse existing facet  
Cache miss: Run extraction prompt and save result
