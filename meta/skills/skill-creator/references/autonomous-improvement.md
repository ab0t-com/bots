# Autonomous Self-Improvement with Skills

Skills are the primary mechanism for an autonomous agent to encode what it learns across sessions. A skill is a persistent memory — it survives context window compaction, session boundaries, and model swaps.

## Why Skills Are the Self-Improvement Mechanism

| Mechanism | Persists across sessions? | Structured? | Triggers automatically? |
|-----------|--------------------------|-------------|------------------------|
| Conversation context | No (compressed/lost) | No | N/A |
| CLAUDE.md instructions | Yes | Partially | Always loaded |
| Skills | Yes | Yes (frontmatter + body + refs) | When description matches |
| Hooks | Yes | Yes (settings.json) | On specific events |
| Subagents | Yes | Yes (agent .md files) | When parent delegates |

Skills are the only mechanism that is **structured, persistent, and conditionally loaded**. CLAUDE.md is always-loaded (context cost). Hooks are event-driven (no knowledge). Subagents are delegation targets (no SOPs). Skills fill the gap.

## The Improvement Loop

```
Session runs → Agent encounters friction
  → Friction signal detected (retries, wrong approach, missing info)
    → Agent analyzes: what was the gap?
      → Agent creates or updates a skill
        → Next session triggers the skill when the same pattern appears
          → Friction eliminated → Loop repeats for new gaps
```

## Identifying Skill Gaps

| Signal During Session | Root Cause | Skill Response |
|----------------------|------------|----------------|
| Agent searched for info repeatedly | Missing domain knowledge | Create `references/` file with the knowledge |
| Agent triggered wrong skill (or none) | Description doesn't match request | Rewrite `description` with more trigger keywords |
| Agent followed skill but got wrong result | Workflow steps wrong or incomplete | Fix SKILL.md body with corrected procedure |
| Agent ignored skill entirely | Description too vague or narrow | Rewrite `description` to cover the trigger surface |
| Agent loaded everything when it needed one thing | Poor progressive disclosure | Split body content into `references/` files |
| Agent rewrote same code multiple times | Missing deterministic script | Add to `scripts/` directory |
| Agent chose wrong approach for the context | Missing decision framework | Add decision table to SKILL.md body |
| Agent asked the user something it should know | Missing SOP or convention | Encode the SOP in SKILL.md body or references |

## Creating a Skill from Session Analysis

After a session with friction:

1. **Extract the SOP** — what sequence of actions eventually worked?
2. **Identify decision points** — where did the agent choose between approaches? What criteria determined the choice?
3. **Separate by disclosure level:**
   - What's needed every time this skill fires? → SKILL.md body
   - What's needed for specific subtasks? → `references/<topic>.md`
   - What's deterministic and reusable? → `scripts/<name>.sh`
4. **Write the description** — what request patterns should trigger this?
5. **Test it** — replay the original task mentally. Does the skill eliminate the friction?

## Updating a Skill from Feedback

When a skill underperforms, apply the minimum viable change:

```
Symptom: Wrong approach chosen
→ Add decision criteria to SKILL.md body (table with conditions → approach mapping)

Symptom: Missing context for edge case
→ Add to existing reference file, or create new reference file

Symptom: Script failed in new environment
→ Fix script, add environment detection / graceful fallback

Symptom: Skill triggered when it shouldn't have
→ Narrow the description keywords
→ Add "Do NOT use when..." guidance to SKILL.md body

Symptom: Skill didn't trigger when it should have
→ Expand the description with more trigger keywords and phrasings

Symptom: Agent loaded 500 lines but only needed 50
→ Move the other 450 lines to references/ files
→ Add pointers in SKILL.md body: "read references/X.md when doing Y"
```

**Don't restructure the whole skill because one reference file is missing.** The minimum change wins.

## Skill Improvement Prioritization

When an agent identifies multiple skill gaps in one session, prioritize by impact:

| Priority | Type | Example |
|----------|------|---------|
| **P0** — Prevents damage | Safety SOP missing, agent did something destructive | Add a hook AND a skill documenting the safe procedure |
| **P1** — Blocks completion | Agent couldn't finish because it lacked critical knowledge | Create skill with the knowledge in references/ |
| **P2** — Causes retries | Agent got there eventually but wasted 5+ turns | Encode the correct approach in SKILL.md body |
| **P3** — Style/quality | Output worked but wasn't ideal | Add examples or conventions to references/ |

## Session Analysis Template

An autonomous agent analyzing its own session for skill gaps:

```markdown
## Session Analysis: [date]

### Friction Points Identified
1. [Describe what went wrong, what was retried, what was missing]
2. [Another friction point]

### Root Cause Classification
| Friction | Type | Priority |
|----------|------|----------|
| Couldn't find deploy process | Missing SOP | P1 |
| Wrote to wrong directory | Missing convention | P2 |
| Reformatted code differently each time | Missing script | P3 |

### Recommended Skill Changes
1. **New skill: `deploy-staging`** — encode the deploy SOP
   - description: "Deploy to staging. Use when..."
   - body: step-by-step deploy workflow
   - references/env-config.md: environment-specific values
2. **Update skill: `project-conventions`** — add directory structure
   - Add: "Generated files go in src/generated/, never src/"
3. **New script: `scripts/format.sh`** — auto-format on write
   - Or better: add a PostToolUse hook instead
```

## Anti-Patterns in Self-Improvement

| Anti-Pattern | Why It Fails | Better Approach |
|-------------|-------------|-----------------|
| Creating a skill for every minor issue | Context bloat from metadata loading | Only create skills for recurring gaps |
| Putting everything in SKILL.md body | High token cost every invocation | Split into references for conditional loading |
| Duplicating CLAUDE.md content in skills | Drift risk, double token cost | One source of truth — either CLAUDE.md or skill |
| Creating skills from one data point | May not generalize | Wait for 2-3 occurrences before encoding |
| Over-engineering skill structure | Complexity defeats purpose | Start minimal, add references only when needed |
