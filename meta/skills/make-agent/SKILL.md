---
name: make-agent
description: Author a Claude Code subagent — a Markdown file with YAML frontmatter in .claude/agents/ that Claude can delegate to. Use when asked to "make an agent", "create a subagent", "write an agent.md", turn a repeatable protocol/SOP into a delegatable worker, or set up a named worker (e.g. a migration bot, a review bot). Covers the exact frontmatter fields, file placement, the system-prompt body, invocation, and a validation checklist.
---

# make-agent — author a Claude Code subagent

A Claude Code **subagent** is a Markdown file with YAML frontmatter. The frontmatter configures it
(name, when to use it, tools, model, …); the body IS its system prompt. Claude delegates to it when a
task matches its `description`, or you invoke it explicitly. Produce an agent someone unfamiliar can
drop in and run correctly.

## When an agent (vs a skill or a plain prompt)
- **Agent**: a *named worker* that runs a repeatable job in its own context with its own tools/prompt
  (a migration bot, a code reviewer, a research fan-out). It's delegated to and reports back.
- **Skill**: instructions loaded INTO the current turn (a how-to the main agent follows). If the thing
  is "here's how to do X", it's a skill; if it's "spin up a worker that does X and reports", it's an agent.
- A one-off task needs neither — just do it.

## Procedure
1. **Pin the job.** One sentence: what recurring task does this agent do, and what does "done" look
   like? If it's not repeatable or delegable, it probably shouldn't be an agent.
2. **Write the frontmatter** (schema below). `name` + `description` are required; add only the optional
   fields you actually need.
3. **Write the body = the system prompt.** It REPLACES Claude Code's default prompt — the agent sees
   only this plus basic environment info. So make it self-contained: role, the exact steps/protocol,
   hard rules, stop/verify conditions, and how to report. Prefer a numbered protocol over prose.
4. **Choose tools deliberately.** Omit `tools` to inherit all; or allowlist the minimum (e.g. a
   read-only reviewer gets `Read, Grep, Glob`). An empty/zero-tool resolution makes Claude refuse to
   launch.
5. **Place the file** (see below), then validate against the checklist.

## File placement
| Path | Scope |
|---|---|
| `.claude/agents/<name>.md` | this project (check into version control for the team) |
| `~/.claude/agents/<name>.md` | all your projects (personal) |

Directories are scanned **recursively** (`agents/review/…` is fine). Create the dir if missing:
```bash
mkdir -p ~/.claude/agents        # or  mkdir -p .claude/agents  for a project agent
$EDITOR ~/.claude/agents/<name>.md
```
No restart needed for most setups; if it doesn't appear, reopen the session.

## Frontmatter schema
```yaml
---
name: my-agent            # REQUIRED. lowercase-with-hyphens, no ':'. This is the agent_type.
description: >-           # REQUIRED. WHEN to delegate here. Short (it costs context). "Use
                          #   proactively to …" encourages auto-delegation. Include trigger phrases.
tools: Read, Grep, Bash   # optional. Comma-separated allowlist. Omit = inherit ALL subagent tools.
disallowedTools: mcp__*   # optional. Denylist, applied before `tools`. Supports mcp__<server>/mcp__*.
model: sonnet             # optional. sonnet|opus|haiku|fable | a full id | inherit (default: inherit).
skills: [name-of-skill]   # optional. Skill names preloaded into the agent at startup.
memory: project           # optional. user|project|local — persistent cross-session memory.
isolation: worktree       # optional. Run in an isolated git worktree copy.
background: true           # optional. Keep it in the background even when foreground is wanted.
effort: high              # optional. low|medium|high|xhigh|max (default: inherit).
color: cyan               # optional. red|blue|green|yellow|purple|orange|pink|cyan (display only).
maxTurns: 40              # optional. Cap agentic turns (resumable).
---
```
Everything except `name` and `description` is optional. Don't add fields you don't need — each line
of frontmatter is config someone has to trust.

## Body (the system prompt)
- Open with the role in one line ("You are X — you do Y.").
- Give the **exact protocol** as numbered steps: each step an action + how it's verified. No "etc."
- State **hard rules** and **stop/verify conditions** ("done" = an observable, tested state, not "looks
  done"). Say what it must NOT do (e.g. never merge, never edit outside the target).
- Say **how to report** back (a concise summary; what to include).

## Invocation
- Natural language that matches the `description` → Claude may auto-delegate.
- `@agent-<name>` (typeahead) → guaranteed.
- Whole session: `claude --agent <name>`, or `{ "agent": "<name>" }` in `.claude/settings.json`.
- Programmatic/one-off (no file): `claude --agents '{ "<name>": { "description": "...", "prompt": "...",
  "tools": ["Read","Bash"], "model": "sonnet" } }'` (JSON uses `prompt` instead of a body).

## Worked example
```markdown
---
name: code-improver
description: Scans changed Go files and suggests readability/perf/best-practice fixes. Use after writing or modifying code.
tools: Read, Grep, Glob
model: sonnet
---

You are a code-improvement specialist. For each issue: name the problem, show the current code, and
give an improved version. Focus on readability, performance, and error handling. Report a short
ranked list; do not edit files unless asked.
```
(For a fuller, protocol-style agent that follows numbered SOPs, routes requests and reports in a
fixed shape, see any bot's `agent.md` in this repository, e.g. `authmesh/agent.md` or `meta/agent.md`.)

## Validation checklist
- [ ] `name` is lowercase-hyphen, unique, no `:`.
- [ ] `description` says WHEN to use it and carries the trigger phrases a user would type.
- [ ] Body is self-contained (role + numbered protocol + hard rules + verify/stop + report shape).
- [ ] `tools` is the minimum needed (or omitted deliberately); it won't resolve to zero tools.
- [ ] `model`/`memory`/`isolation`/etc. are set only if actually needed.
- [ ] File is at `.claude/agents/<name>.md` (project) or `~/.claude/agents/<name>.md` (personal).
- [ ] A stranger could invoke it and get the intended result the first time.

## Reference
Official docs: https://code.claude.com/docs/en/sub-agents
