---
name: quinn-uj
description: >-
  Client-side SOPs for testing an HTTP service with uj (user journeys, end-to-end and API tests,
  honest PASS/FAIL/VOID verdicts). Use when helping a team install uj, start a project and set
  targets (harness.toml), describe per-journey setup and test users (environment.json, {env:NAME}
  secrets, two-user isolation), decide what to test (test types, risks, realistic sessions, edge
  cases, abuse, missteps), write or edit a journey (uj new, capture, expect, finally), make
  assertions that catch bugs, test across services or a UI (run: and browser steps), run and read
  verdicts, debug or resume a failure, run the suite in CI (--strict, JUnit/CTRF, --parallel,
  --shard, --changed), manage many projects and suites (tags, personas, coverage, explain), keep
  journeys current when the API changes, check OpenAPI drift (uj contract), think about load, or
  use uj off-label (uj verdict, coverage, living docs). Triggers: "uj", "user journey", "test my
  API", "end to end test", "what should I test", "edge cases", "my test is VOID", "flaky test",
  "run in CI", "harness.toml", "environment.json", "OpenAPI drift".
---

# quinn-uj

Twenty short pages, one per job, for teams testing their service with uj. This file only routes;
the SOPs are the references. Load the one for the job, follow it in order, and respect its
**Coming** markers (not built yet; each has a *Today:* workaround).

## Non-negotiables (restated from the SOPs)
- uj never guesses a target: `--base` › `--target` › `$UJ_BASE` › `harness.toml`. Name the target
  before every run. Never production: journeys create real data.
- Preview before any change (show the journey/diff) → explicit yes → apply. `uj run` and `uj doctor`
  call the service: ask first. `run:` steps execute shell: review before running others' journeys.
- Secrets via `{env:NAME}`, never in files; never print a secret.
- Never weaken an expectation or delete a failing journey to get green. VOID = environment, not bug.
- No global config: everything that affects a test lives in the project (`harness.toml`,
  `environment.json`, `journeys/`, `runs/`). The only per-user file is the `uj projects` list.
- Memory: start every session with `uj where`, load `.uj/product.context` then only what the task
  needs; write back risks/decisions/findings with a preview; never a secret in `.uj/`.

## The SOPs (relative to this file)
| job | file |
|---|---|
| map of everything | [../../00_index.md](../../00_index.md) |
| how uj tests your product | [../../01_sop_system_testing_model_for_clients.md](../../01_sop_system_testing_model_for_clients.md) |
| day zero, end to end | [../../02_sop_system_day_zero_acme_tests_invoicer.md](../../02_sop_system_day_zero_acme_tests_invoicer.md) |
| install, update, where things live | [../../03_sop_system_install_update_and_where_things_live.md](../../03_sop_system_install_update_and_where_things_live.md) |
| start a project and targets | [../../04_sop_system_start_a_project_and_targets.md](../../04_sop_system_start_a_project_and_targets.md) |
| describe setup (environment.json) | [../../05_sop_system_describe_setup_environment.md](../../05_sop_system_describe_setup_environment.md) |
| choose what to test | [../../06_sop_system_choose_what_to_test.md](../../06_sop_system_choose_what_to_test.md) |
| write a user journey | [../../07_sop_system_write_a_user_journey.md](../../07_sop_system_write_a_user_journey.md) |
| assertions that catch bugs | [../../08_sop_system_assertions_that_catch_bugs.md](../../08_sop_system_assertions_that_catch_bugs.md) |
| realistic sessions and edge cases | [../../09_sop_system_realistic_sessions_and_edge_cases.md](../../09_sop_system_realistic_sessions_and_edge_cases.md) |
| end to end across services and the UI | [../../10_sop_system_end_to_end_across_services_and_ui.md](../../10_sop_system_end_to_end_across_services_and_ui.md) |
| run, read verdicts, debug | [../../11_sop_system_run_read_verdicts_and_debug.md](../../11_sop_system_run_read_verdicts_and_debug.md) |
| CI and the team workflow | [../../12_sop_system_ci_and_team_workflow.md](../../12_sop_system_ci_and_team_workflow.md) |
| manage many projects and suites | [../../13_sop_system_manage_many_projects_and_suites.md](../../13_sop_system_manage_many_projects_and_suites.md) |
| edit and maintain journeys | [../../14_sop_system_edit_and_maintain_journeys.md](../../14_sop_system_edit_and_maintain_journeys.md) |
| API contract and drift | [../../15_sop_system_api_contract_and_drift.md](../../15_sop_system_api_contract_and_drift.md) |
| load and performance | [../../16_sop_system_load_and_performance.md](../../16_sop_system_load_and_performance.md) |
| everything else uj can do | [../../17_sop_system_everything_else_uj_can_do.md](../../17_sop_system_everything_else_uj_can_do.md) |
| troubleshooting | [../../18_sop_system_troubleshooting.md](../../18_sop_system_troubleshooting.md) |
| rules for honest tests | [../../19_sop_system_rules_for_honest_tests.md](../../19_sop_system_rules_for_honest_tests.md) |
| every Coming item in one table | [../../GAPS.md](../../GAPS.md) |

## Companions (load by name when an SOP points there)
`uj-cli` (driving the binary: flags, `--json`, exit codes, verdict protocol); `uj-authoring` (the
journey file format, every `expect` form, lint rules); `uj-journey-design` (what to test and how to
judge a journey before writing it); `usability-audit-sop` (a paired black-box/white-box audit of a
product or its docs by two role-playing assistants — the "test it as a stranger" use in SOP 17). For a service on the ab0t mesh: `ally-mesh-client` (sign-in and
keys) from Ally's folder.
