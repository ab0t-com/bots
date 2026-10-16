# Test your product the way your users use it, with uj

**Who this is for.** Anyone who wants to know that their HTTP service really works for the people using it: a product manager who wants the important stories protected, a QA engineer building a suite, a developer who wants a CI gate that tells "the product broke" from "the environment broke". The tool is **uj**, one command-line program; the tests are readable user-journey files in your repo. The running example is **Acme**'s **`invoicer`**, a small invoicing API (yours will differ).

**How to use it.** Read 01 and 02 once. Then 03 → 07 in order for your first green journey, 08–10 to make your tests catch real bugs, 11–12 to run them every day and in CI, and the rest as jobs come up. Each SOP has the same shape: what it is for, what to have ready, numbered steps with exact commands, what you will see, what to do when it goes wrong, what is **Coming** (not built yet, with today's workaround), and where to go next.

**Three things to know before any command.** uj never guesses which service to test: the target comes from `harness.toml` or `--base`, and the first line of every run names it. Journeys create real data (sign-ups, records), so point targets at dev or staging, **never production**. Passwords and keys never go in files: write `{env:NAME}` and uj reads the environment variable at run time.

**Quinn.** The agent in this folder (`agent.md`) follows these SOPs for you: plain words first, a preview and your yes before anything changes or runs, never prints a secret, never turns a red test green by weakening it.

## The journey

| # | SOP | one line |
|---|---|---|
| 01 | [How uj tests your product](01_sop_system_testing_model_for_clients.md) | Journeys, the five verdicts, the project files and memory, no global config. |
| 02 | [Day zero: Acme tests invoicer](02_sop_system_day_zero_acme_tests_invoicer.md) | The whole first day, in order. |
| 03 | [Install, update, where things live](03_sop_system_install_update_and_where_things_live.md) | The one-liner on every OS, confirming, updating and rolling back, every place uj keeps state, config layers. |
| 04 | [Start a project and targets](04_sop_system_start_a_project_and_targets.md) | `uj init`, the layout, dev and staging targets, `--target`, `UJ_BASE`, several projects in one repo. |
| 05 | [Describe setup](05_sop_system_describe_setup_environment.md) | `environment.json`: what runs before every journey, test users, `{env:NAME}` secrets, two users, `uj doctor`. |
| 06 | [Choose what to test](06_sop_system_choose_what_to_test.md) | Test types, risk first, realistic sessions over unit tests, outcome-first journeys. |
| 07 | [Write a user journey](07_sop_system_write_a_user_journey.md) | `uj new` to a green run: story, steps, captures, cleanup, explain, lint, validate. |
| 08 | [Assertions that catch bugs](08_sop_system_assertions_that_catch_bugs.md) | Every expectation form, lists, schemas, proving something is gone, the two traps. |
| 09 | [Realistic sessions and edge cases](09_sop_system_realistic_sessions_and_edge_cases.md) | Sessions with checkpoints, fragments, missteps, abuse, isolation, edge inputs, coverage. |
| 10 | [End to end across services and the UI](10_sop_system_end_to_end_across_services_and_ui.md) | One target per run; `run:` steps, browser steps, async work, several services today. |
| 11 | [Run, read verdicts, debug](11_sop_system_run_read_verdicts_and_debug.md) | `uj run`, the verdicts and exit codes, reading a failure, VOID, resume, history. |
| 12 | [CI and the team workflow](12_sop_system_ci_and_team_workflow.md) | A CI job, exit codes 1 vs 2, secrets, parallel, shards, changed-only, flaky gate, reviews. |
| 13 | [Manage many projects and suites](13_sop_system_manage_many_projects_and_suites.md) | Organising suites, tags and personas, the risk map, the manager's report. |
| 14 | [Edit and maintain journeys](14_sop_system_edit_and_maintain_journeys.md) | When the API changes, pinned bugs, flaky journeys, upgrading uj. |
| 15 | [API contract and drift](15_sop_system_api_contract_and_drift.md) | `uj contract`: OpenAPI completeness, parity between versions, real-traffic conformance; `expect.schema`. |
| 16 | [Load and performance](16_sop_system_load_and_performance.md) | What uj can and cannot do for performance today, and the practical alternatives. |
| 17 | [Everything else uj can do](17_sop_system_everything_else_uj_can_do.md) | Honest scoring of any test, legacy scripts, living docs, comparing two implementations, agents. |
| 18 | [Troubleshooting](18_sop_system_troubleshooting.md) | Every uj message, with meaning and fix. |
| 19 | [Rules for honest tests](19_sop_system_rules_for_honest_tests.md) | The rules Quinn keeps, and why. |

## Also in this folder

- `agent.md`, Quinn; `skills/quinn-uj/SKILL.md`, the skill that points Quinn at these SOPs; `skills/uj-cli`, `skills/uj-authoring`, `skills/uj-journey-design`, `skills/usability-audit-sop`, uj's own skills; `README.md`, installing all of it.
- `GAPS.md`, every **Coming** item in one table.
- Putting the service you test on the ab0t mesh (sign-in, keys): Ally, in [`../authmesh/`](../authmesh/00_index.md).
