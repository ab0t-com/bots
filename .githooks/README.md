# Git hooks — secret scanning (no CI workflows by design)

Two hooks run gitleaks with this repo's `.gitleaks.toml`:

| Hook | Scans | Blocks |
|---|---|---|
| `pre-commit` | the staged changes | the commit |
| `pre-push` | every commit about to be pushed | the push |

Enable once per clone of the bots repo (never in a parent monorepo — it would apply to that whole repo):

```bash
git config core.hooksPath .githooks
```

If gitleaks is not installed the hooks print a warning and let the commit through — install it:
https://github.com/gitleaks/gitleaks#installing

A false positive? Write example values as obvious placeholders (`ab0t_sk_live_EXAMPLE…`, `xxxx`, `<your-key>`), or add a
narrow rule to `.gitleaks.toml`. Never allowlist a whole folder.
