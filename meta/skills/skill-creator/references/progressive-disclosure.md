# Progressive Disclosure — The Core Architecture of Skills

Progressive disclosure is the entire architecture of skills. The context window is shared with system prompts, conversation history, other skills, and the actual task. Every token in a skill displaces something else.

## Three Loading Levels

```
Level 1: ALWAYS loaded     →  name + description         →  ~100 words max
Level 2: Loaded on trigger →  SKILL.md body              →  <500 lines
Level 3: Loaded on demand  →  references/, scripts/      →  unlimited
```

**Level 1 decides if the skill fires.** The `description` field is the trigger — if it doesn't match the user's request, the body never loads. All "when to use" information lives here. Not in the body. The body loads AFTER triggering — too late for trigger decisions.

**Level 2 is the working memory.** It loads when the skill activates. It should contain the workflow the agent follows, pointers to reference files, and the minimum context needed to start working. NOT exhaustive documentation.

**Level 3 is the library.** Reference files, scripts, assets. Loaded only when the agent determines it needs them. This is where detailed schemas, API docs, examples, and domain-specific knowledge live.

## The Progressive Disclosure Test

For every piece of information in a skill, ask:

| Question | If yes → |
|----------|----------|
| Does the agent need this to decide whether to use the skill? | Level 1 (description) |
| Does the agent need this for every invocation? | Level 2 (SKILL.md body) |
| Does the agent need this only for specific subtasks? | Level 3 (references/) |
| Does the agent already know this? | Delete it |

## Structuring SKILL.md as a Router

SKILL.md body should be a **router**, not an encyclopedia:

```markdown
# Skill Name

## Quick Start
[Minimal working example — 5-10 lines]

## Workflow
[Decision tree / step-by-step procedure]

## When to Read References
- **[schemas.md](references/schemas.md)** — read when writing queries or migrations
- **[troubleshooting.md](references/troubleshooting.md)** — read when errors occur
- **[patterns.md](references/patterns.md)** — read when choosing between approaches

## Key Decisions
[2-3 critical decision points with criteria, not full explanations]
```

The agent reads SKILL.md, understands the workflow, then pulls specific references as needed. It never loads everything at once.

## Reference File Splitting Patterns

### Pattern 1: Domain-Split

When a skill covers multiple domains, split by domain so the agent only loads what's relevant:

```
my-skill/
├── SKILL.md                    # Router: "read the reference for your domain"
└── references/
    ├── aws.md                  # Only for AWS tasks
    ├── gcp.md                  # Only for GCP tasks
    └── azure.md                # Only for Azure tasks
```

When a user asks about AWS, the agent only reads `aws.md`.

### Pattern 2: Workflow + Detail Split

Keep the workflow in SKILL.md, put the details in references:

```
my-skill/
├── SKILL.md                    # Workflow steps + decision points
└── references/
    ├── api-reference.md        # Full API surface (loaded when calling APIs)
    ├── error-codes.md          # Error catalog (loaded when debugging)
    └── examples.md             # Worked examples (loaded when stuck)
```

### Pattern 3: Script + Instructions Split

Deterministic operations go in scripts, instructions for using them in SKILL.md:

```
my-skill/
├── SKILL.md                    # "Run scripts/deploy.sh with these args..."
├── scripts/
│   ├── deploy.sh               # Tested, deterministic deploy
│   └── rollback.sh             # Tested, deterministic rollback
└── references/
    └── deploy-config.md        # Environment-specific config values
```

### Pattern 4: Conditional Details

Show basic content in SKILL.md, link to advanced content:

```markdown
# DOCX Processing

## Creating documents
Use docx-js for new documents. See [DOCX-JS.md](references/docx-js.md).

## Editing documents
For simple edits, modify the XML directly.

**For tracked changes**: See [REDLINING.md](references/redlining.md)
**For OOXML details**: See [OOXML.md](references/ooxml.md)
```

The agent reads the advanced references only when the user needs those features.

## Reference File Rules

- **TOC required if >100 lines** — the agent needs to see the full scope when previewing
- **One level deep** — all reference files link directly from SKILL.md, no nested subdirectories
- **Self-contained** — each reference file should be readable without SKILL.md context
- **Use the same information-dense formatting** — tables over prose, one fact per line
- **Include grep patterns in SKILL.md for very large references** (>10k words) so the agent can search without loading the whole file

## Why Progressive Disclosure Matters for Self-Improvement

When an autonomous agent creates a skill from session analysis, the progressive disclosure split determines whether the skill actually helps or just adds context bloat:

- **Good split**: SKILL.md has the decision tree (50 lines), references have the detailed schemas (500 lines). Next session loads 50 lines always, 500 lines only when querying.
- **Bad split**: Everything in SKILL.md (550 lines). Next session loads 550 lines for every invocation, even when the task doesn't need the schemas.

The difference compounds across skills. An agent with 10 well-split skills loads ~500 words of metadata + ~250 lines of workflow for the triggered skill. An agent with 10 monolithic skills loads ~500 words of metadata + ~500 lines of everything for the triggered skill. That's 250 lines of context window lost to information the agent won't use.

## Common Disclosure Mistakes

| Mistake | Why It Hurts | Fix |
|---------|-------------|-----|
| "When to Use" section in body | Body loads after triggering — too late | Move to `description` |
| All examples in SKILL.md | Most invocations don't need examples | Move to `references/examples.md` |
| API docs inline | Bloats every invocation | Move to `references/api.md` |
| Schema definitions inline | Only needed for some subtasks | Move to `references/schema.md` |
| Troubleshooting guide inline | Only needed when errors occur | Move to `references/troubleshooting.md` |
| Everything in one reference file | Agent loads all even when it needs one section | Split by domain or task type |

## Notice

The three-level loading model and the reference-splitting patterns (domain split, conditional
details, the DOCX example) are adapted from Anthropic's `skill-creator` skill,
<https://github.com/anthropics/skills/tree/main/skills/skill-creator>, Copyright Anthropic, PBC,
licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
**Modified:** reworded and extended (the disclosure test, router structure, self-improvement section,
mistakes table) for this repository.
