# Skill formats by harness

The portable core is the [Agent Skills format](SPEC.md): a folder named after the skill, holding a
`SKILL.md` with `name` + `description` frontmatter and a Markdown body, plus optional `scripts/`,
`references/` and `assets/`. Claude Code, Gemini CLI and Codex all read that format. What differs is
**where they look** and **which extra fields they honour**. Harnesses change often: treat the table
below as a starting point (checked 2026-10-16) and confirm in each harness's own docs before you
rely on a detail.

## Where each harness looks

| harness | project / repo | user | official docs |
|---|---|---|---|
| Claude Code | `.claude/skills/<name>/SKILL.md` (also nested `<subdir>/.claude/skills/`) | `~/.claude/skills/<name>/SKILL.md` | <https://code.claude.com/docs/en/skills> |
| Gemini CLI | `.gemini/skills/<name>/` or `.agents/skills/<name>/` | `~/.gemini/skills/` or `~/.agents/skills/` | <https://geminicli.com/docs/cli/skills/> |
| Codex | `.agents/skills/<name>/` in the working folder, its parents, up to the repo root | `$HOME/.agents/skills/` | <https://learn.chatgpt.com/docs/build-skills> |

`.agents/skills/` is the cross-client convention described in the Agent Skills
[client guide](https://agentskills.io/client-implementation/adding-skills-support); Claude Code reads
`.claude/skills/`.

## Extra fields and files

- **Claude Code** honours the spec fields and adds its own, among them `disable-model-invocation`,
  `user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork` with `agent`, `hooks` and
  `paths`. The full list is in its docs. Other harnesses ignore fields they do not know.
- **Gemini CLI** loads a skill when the model calls its `activate_skill` tool and the user consents;
  the docs describe discovery and activation, not extra frontmatter.
- **Codex** reads `name` and `description`; display metadata, implicit-invocation policy and tool
  dependencies go in an optional `agents/openai.yaml` beside `SKILL.md`. Users invoke a skill
  explicitly with `$<name>`, or Codex picks it from the description.

## Porting a skill

1. Keep the folder as is; make sure `name` matches the folder and follows the spec's rules
   (lowercase letters, digits, single hyphens).
2. Put everything the agent needs to decide *when* to use it in `description`.
3. Copy or symlink the folder into the target harness's directory above (or `.agents/skills/` to
   reach the harnesses that read it).
4. Harness-specific fields stay; they are ignored where unsupported. If the skill depends on one
   (for example Claude Code's `context: fork`), say so in the body or in `compatibility`.
5. Run `skills-ref validate ./<skill>` (see [SPEC.md](SPEC.md)) and try the skill once in the
   target harness.
