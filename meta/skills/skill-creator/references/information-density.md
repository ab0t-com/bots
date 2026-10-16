# Information Density — Writing Skills That Earn Their Token Cost

## Core Principle

Every line in a skill must earn its place through information content. The context window is a shared resource. Default assumption: the agent is already very smart — only add knowledge it doesn't already have.

## One Line, One Fact

LLMs read line-by-line. Structure knowledge so each line is a complete, actionable fact:

```markdown
# Dense (good) — each line is a self-contained fact
**JWT**: Short-lived, stateless, user sessions → validate via JWKS endpoint
**API Key**: Long-lived, revocable, service-to-service → validate via auth service lookup
**Both**: When supporting multiple auth patterns → check Authorization header first, fall back to X-API-Key

# Sparse (bad) — spreads one fact across many lines
## JWT Tokens
JWT tokens are used for user sessions.
They are short-lived and stateless.
To validate them, you use the JWKS endpoint.
```

The dense version is 3 lines. The sparse version is 5 lines (plus heading). Same information, 40% more tokens.

## Line-Based Knowledge Encoding

For structured data, encode the full record on one line:

```markdown
**Field**: service_id → **Type**: string → **Required**: yes → **Purpose**: becomes subdomain → **Pattern**: lowercase-alphanumeric → **Example**: my-service
```

NOT:

```markdown
**Field**: service_id
**Type**: string
**Required**: yes
**Purpose**: becomes subdomain
**Pattern**: lowercase-alphanumeric
**Example**: my-service
```

The first format is 1 line. The second is 6 lines. Same information. For a schema with 20 fields, that's 20 lines vs 120 lines — 100 lines of context window saved.

## Tables Over Prose

When comparing options, formats, or decisions, always use tables:

```markdown
| Situation | Approach | Why |
|-----------|----------|-----|
| Simple CRUD | Direct SQL | Overhead of ORM not justified |
| Complex joins | Query builder | Composability without full ORM |
| Schema migrations | Alembic script | Deterministic, version-controlled |
```

NOT:

```markdown
For simple CRUD operations, use direct SQL because the overhead of an ORM is not justified.
For complex joins, use a query builder because it provides composability without a full ORM.
For schema migrations, use an Alembic script because it is deterministic and version-controlled.
```

Tables are scannable. Prose requires sequential reading. Tables make decision points explicit.

## Patterns Over Instructions

Encode reusable patterns, not step-by-step instructions the model could derive:

```markdown
## The DISCOVER Pattern
WHEN: Unfamiliar codebase or domain
DO: Directory scan → Grep for entry points → Read key files → Map dependencies
VERIFY: Can explain the data flow end-to-end
OUTPUT: Mental model written to workspace notes

## The VALIDATE Pattern
WHEN: Before any destructive or irreversible operation
DO: Check preconditions → Dry run if possible → Verify with user if ambiguous
VERIFY: All preconditions met, rollback path exists
OUTPUT: Go/no-go decision with reasoning
```

Patterns are reusable across contexts. Step-by-step instructions are single-use.

## Problem-First Documentation

Structure: PROBLEM → CONTEXT → SOLUTION → VERIFICATION

```markdown
**Problem**: Services on internal IPs need public HTTPS access
**Why**: Can't share localhost:3000 with clients
**Solution**: API creates https://name.domain.com instantly
**Verification**: curl https://your-service.domain.com returns 200
```

NOT:

```markdown
## Overview
This section describes how to set up public HTTPS access for services.

## Background
When you have services running on internal IPs, you may want to...
```

Problem-first gets to the point. The agent knows immediately if this section is relevant.

## Grep-Optimized Sections

For troubleshooting and reference sections, use unique, searchable markers:

```markdown
### "Error: Permission denied" → **Cause**: Incorrect scope → **Fix**: Add permission to agent → **Prevent**: Check permissions first
### "Error: File not found" → **Cause**: Wrong path → **Fix**: Use absolute paths → **Prevent**: Verify with ls first
```

Each error is one line. The agent can grep for the error message and find the fix without loading the entire section.

## Decision Documentation

```markdown
### When to use JWT vs API Keys
**JWT when**: User sessions, short-lived, stateless → Example: Web app login
**API Keys when**: Service-to-service, long-lived, auditable → Example: CI/CD pipeline
**Both when**: Supporting multiple auth patterns → Example: Public API
```

Decision points encoded as single lines. The agent can read one line and know the answer.

## What to Delete

Challenge every piece of information:

| Content | Keep? | Why |
|---------|-------|-----|
| Knowledge the model already has (Python syntax, HTTP methods) | No | Token waste |
| "In this section we will discuss..." | No | Filler |
| Repetition of the same fact in different words | No | Redundancy |
| Verbose explanations of simple concepts | No | Model can infer |
| Examples that don't add information beyond the instruction | No | Token waste |
| Context the agent doesn't need to act | No | Noise |
| Detailed edge cases that occur <1% of the time | Move to references | Not needed every invocation |

## Measuring Density

A rough heuristic: count the number of **actionable facts** per 100 lines.

- **High density**: 50+ facts per 100 lines (tables, one-liners, patterns)
- **Medium density**: 25-50 facts per 100 lines (mixed prose and structure)
- **Low density**: <25 facts per 100 lines (verbose prose, filler, repetition)

Skills should target high density in SKILL.md body, medium density acceptable in reference files.
