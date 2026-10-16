---
name: skill-creator
description: Guide for creating, evaluating, and improving skills across coding agent harnesses (Claude Code, Gemini CLI, Codex). Use when creating a new skill, updating an existing skill, porting a skill between harnesses, auditing skill quality, or designing a skill for autonomous self-improvement loops. Covers the Agent Skills open standard, SKILL.md anatomy, frontmatter fields, progressive disclosure, bundled resources, where each harness looks for skills, and common anti-patterns.
license: Apache-2.0 (portions adapted from Anthropic's skill-creator; see the notice at the end)
---

# Skill Creator

Create effective, portable skills for coding agent harnesses.

## What Skills Are

Skills are modular packages that extend an agent's capabilities with specialized knowledge, workflows, and tools. They transform a general-purpose agent into a domain specialist by providing procedural knowledge that no model fully possesses.

Skills follow the [Agent Skills open standard](https://agentskills.io) ([adapted copy of the spec](references/SPEC.md)), a folder format that Claude Code, Gemini CLI, Codex and other agent products read.

## Anatomy

```
skill-name/               # folder name == frontmatter `name`
├── SKILL.md              # Required — YAML frontmatter + markdown body
├── scripts/              # Optional — deterministic executable code
├── references/           # Optional — docs loaded on demand into context
└── assets/               # Optional — files used in output (templates, images)
```

**Frontmatter (the standard):**

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | 1-64 chars, lowercase letters, digits and single hyphens; must match the folder name |
| `description` | Yes | What it does + when to trigger (the primary trigger mechanism); max 1024 chars |
| `license` | No | Licence name or bundled licence file |
| `compatibility` | No | Environment requirements, only if needed; max 500 chars |
| `metadata` | No | String-to-string map for your own keys |
| `allowed-tools` | No | Pre-approved tools (experimental; support varies) |

Harnesses add their own fields (Claude Code: `disable-model-invocation`, `user-invocable`, `model`, `effort`, `context: fork`, `hooks`, `paths`, …) and look in different folders (Claude Code: `.claude/skills/` and `~/.claude/skills/`; Gemini CLI and Codex: `.agents/skills/` and `~/.agents/skills/`, Gemini also `.gemini/skills/`). Details and official links: [formats-by-harness.md](references/formats-by-harness.md).

## Core Design Principles

### 1. Concise Is Key

The context window is shared with system prompts, conversation history, other skills, and user requests. Every token in a skill displaces something else.

**Default assumption: the agent is already very smart.** Only include knowledge the agent doesn't already have. Challenge every paragraph: "Does this justify its token cost?"

Prefer concise examples over verbose explanations.

### 2. Progressive Disclosure

Skills use a three-level loading system:

| Level | What loads | Size target | When |
|-------|-----------|-------------|------|
| **Metadata** | `name` + `description` | ~100 words | Always in context |
| **Body** | SKILL.md markdown | <500 lines | When skill triggers |
| **Resources** | `references/`, `scripts/` | Unlimited | On demand by agent |

The `description` field is the primary trigger mechanism — it determines whether the skill activates. All "when to use" information belongs in `description`, not in the body.

### 3. Match Freedom to Fragility

| Freedom level | When to use | Format |
|---------------|-------------|--------|
| **High** (text guidance) | Multiple valid approaches, context-dependent | Markdown instructions |
| **Medium** (pseudocode) | Preferred pattern exists, some variation OK | Parameterized scripts |
| **Low** (exact scripts) | Fragile operations, consistency critical | Deterministic `scripts/` |

## Creating a Skill

### Step 1: Define the Trigger Surface

Write the `description` first. It must answer:
- What does this skill do?
- What user requests should trigger it?
- What keywords, file types, or contexts are relevant?

```yaml
# Bad — vague, won't trigger reliably
description: Helps with databases

# Good — specific triggers, clear scope
description: Create, query, and optimize PostgreSQL databases. Use when writing SQL queries, designing schemas, creating migrations, optimizing slow queries (EXPLAIN ANALYZE), setting up connection pools, or debugging pg_stat errors.
```

### Step 2: Plan Bundled Resources

For each concrete use case, ask:
- Am I rewriting the same code every time? → `scripts/`
- Do I need reference docs while working? → `references/`
- Do I need template files in the output? → `assets/`

### Step 3: Write SKILL.md Body

Structure the body as a workflow the agent follows:

```markdown
# Skill Name

## Quick Start
[Minimal example to get working immediately]

## Workflow
[Step-by-step procedure with decision points]

## Reference Files
- **[schemas.md](references/schemas.md)** — database schemas, read when querying
- **[optimization.md](references/optimization.md)** — read when EXPLAIN shows seq scans

## Common Patterns
[2-3 concise examples covering the most frequent cases]
```

### Step 4: Organize References

Keep SKILL.md under 500 lines. Split by domain or variant:

```
my-skill/
├── SKILL.md                    # Core workflow + navigation
└── references/
    ├── aws.md                  # Only loaded for AWS tasks
    ├── gcp.md                  # Only loaded for GCP tasks
    └── troubleshooting.md      # Only loaded when errors occur
```

Reference files longer than 100 lines should include a table of contents. Keep references one level deep from SKILL.md — no nested subdirectories.

### Step 5: Validate

Run `skills-ref validate ./my-skill` (the standard's reference validator; see [SPEC.md](references/SPEC.md)), then try the skill on a real request in each harness you target.

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| "When to Use" section in body | Body loads after triggering — too late | Move to `description` |
| README.md, CHANGELOG.md inside the skill | Clutter for humans, not agents | Delete them |
| Entire API docs in SKILL.md | Bloats context for every invocation | Move to `references/` |
| Duplicated content across files | Wastes tokens, risks drift | Single source of truth |
| Deeply nested references | Agent can't discover them | Flat `references/` dir |
| Generic instructions the model already knows | Token waste | Delete them |
| `name` that differs from the folder, or uses `_` / capitals | Breaks the standard; some harnesses warn or skip | Lowercase-hyphen, equal to the folder |

## Cross-Harness Portability

Skills are most portable when the core content is plain markdown instructions and only the standard frontmatter is required.

**To port a skill:** copy (or symlink) the whole folder into the target harness's skills directory; `.agents/skills/` reaches Gemini CLI and Codex, `.claude/skills/` reaches Claude Code. Fields a harness does not know are ignored, so harness-specific fields can stay; if the skill depends on one, say so in `compatibility`. See [formats-by-harness.md](references/formats-by-harness.md).

## Skill Quality Checklist

Before deploying a skill, verify:

- [ ] `name` equals the folder name and follows the standard (lowercase, digits, single hyphens)
- [ ] `description` covers all trigger scenarios (specific keywords, file types, contexts)
- [ ] Body is under 500 lines
- [ ] No information the model already knows
- [ ] No "When to Use" section in the body (belongs in `description`)
- [ ] References are one level deep, with TOC if >100 lines
- [ ] Scripts are tested and deterministic
- [ ] No README, CHANGELOG, or auxiliary docs
- [ ] Instructions use imperative form ("Create the migration" not "You should create")

## Deep Dives

- **[SPEC.md](references/SPEC.md)** — the Agent Skills format rules (adapted copy); read when in doubt about a field or name
- **[progressive-disclosure.md](references/progressive-disclosure.md)** — read when designing skill loading levels and splitting content
- **[information-density.md](references/information-density.md)** — read when writing skill content for maximum token efficiency
- **[autonomous-improvement.md](references/autonomous-improvement.md)** — read when creating skills from session analysis or feedback loops
- **[formats-by-harness.md](references/formats-by-harness.md)** — read when porting skills between Claude Code, Gemini CLI and Codex

## Autonomous Skill Improvement

When an agent uses a skill and encounters friction, it can improve the skill:

1. **Identify the gap** — What was missing, wrong, or ambiguous?
2. **Classify the fix** — Is it a trigger issue (description), a workflow issue (body), or a reference gap?
3. **Apply the minimum change** — Edit the specific section. Don't restructure the whole skill.
4. **Test the change** — Use the skill on the original task to verify improvement.

Common improvement signals:
- Agent had to search for information the skill should have provided → add to `references/`
- Agent triggered the wrong skill → refine `description` keywords
- Agent followed the skill but produced wrong output → fix the workflow steps
- Agent ignored the skill entirely → `description` didn't match the request pattern

## Notice

Portions of this skill (the "Concise Is Key" and "Match Freedom to Fragility" principles, the
three-level progressive-disclosure model, and the advice to keep README/CHANGELOG files out of a
skill) are adapted from Anthropic's `skill-creator` skill,
<https://github.com/anthropics/skills/tree/main/skills/skill-creator>, Copyright Anthropic, PBC,
licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
**Modified:** reworded, reorganised and extended (harness formats, quality checklist, autonomous
improvement) for this repository. The format rules come from the Agent Skills specification; see
the notice in [references/SPEC.md](references/SPEC.md).
