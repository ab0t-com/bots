# 01 · How uj tests your product, in plain words

**What this is for.** The few ideas you need before writing a single test, so every later SOP reads easily. Ten minutes. The running example is **Acme**'s **`invoicer`**, a small invoicing API (yours will differ).

**A user journey is a person getting something done.** Not "call `POST /invoices`", but *"a new customer signs up, sends their first invoice, and nobody else can see it."* A journey is one plain-text file (YAML or JSON) that tells that story step by step. Every step starts with an **intent** in human words; under it sit the mechanics an engineer fills in: the request, what to remember from the answer, and what the answer must contain. A product manager writes and reads the intents; an engineer fills the mechanics; the same file serves both.

**uj runs the story against your real service and gives one honest verdict.** For each journey uj runs any setup you described, makes the real HTTP calls in order, carries values from one step to the next (an invoice id created in step 3 is used in step 5), checks every expectation, cleans up, and says:

| verdict | means | what you do |
|---|---|---|
| **PASS** | every expectation held | nothing |
| **FAIL** | the service answered and an expectation did not hold | a bug, or a wrong expectation in the test; read the step's reason and the response |
| **VOID** | uj could not judge: the service did not answer, setup failed, or a value the test needs was never provided | fix the environment (`uj doctor` says what); do not file a bug |
| **SKIP** | the journey needs a capability this environment does not have | nothing; it is expected |
| **INCONCLUSIVE** | the journey checked nothing | add expectations; a test that proves nothing is not a pass |

That table is the heart of uj. Most test setups blur "the product is broken" and "the test could not run" into the same red; uj keeps them apart, and its exit code does too (`0` pass, `1` a real failure, `2` the environment broke).

## The files you will meet

| file | what it holds | who edits it |
|---|---|---|
| `harness.toml` | **which service** to test: one or more targets (`dev`, `staging`) by URL | whoever owns the environments |
| `environment.json` | **setup** that runs before *every* journey, for example sign up a fresh user and log in; what it captures becomes `{token}`, `{user}` … in every journey. It may be empty | an engineer, with `uj doctor` to check it |
| `journeys/*.yaml` | **the tests**, one journey per file; sub-folders are fine | product, QA and engineering |
| `HARNESS.md` | how a teammate runs the tests | anyone |
| `.uj/` | the project's **memory**: what the product is, the risk register, the team's conventions, decisions and bugs found | anyone, with Quinn; never secrets |

`uj init` creates all of them, at the root of your git repository (one project per repo). uj finds `harness.toml` by walking up from where you are, so commands work from any sub-folder. There is **no global or per-user configuration**: nothing about a test depends on who runs it, so a teammate's laptop and your CI get the same answer. Run history lives in `runs/` beside `harness.toml` and is git-ignored. Lost? `uj where` shows the
project, its target, its journeys, the last run and the risks nothing tests yet; `uj projects` lists
every uj project you have used.

## Words you will meet

- **Target** — the URL of the service under test. Set it once in `harness.toml`; `--base <url>` overrides it for one run. uj never guesses one.
- **Setup** (the environment) — what runs before each journey to give it fresh state. Every journey gets its own fresh setup, so journeys never share a user or leak into each other.
- **Epic** — a journey with several steps that share state and stop at the first failure (most journeys).
- **Capture** — remembering a value from a response (`capture: { invoice_id: $.id }`) to use later as `{invoice_id}`. Mark secrets (`secret:token`) and uj masks them everywhere.
- **`{env:NAME}`** — a value read from an environment variable at run time; how passwords stay out of your repo.
- **Abuse step** — a step where an outsider tries something and must be refused. **Misstep** — a real user's wrong turn that the product should handle gracefully.
- **Tenant** — an isolated customer account, for products that have them; setup can create a fresh one per journey.

## What good tests look like here

A good suite starts from a **risk register** (`.uj/risks.context`): what would hurt your users or
your business if it broke, in priority order. Every journey names the risks it covers, and
`uj coverage` lists the risks nothing covers yet, so "what should we test next?" has an answer.

A good journey is a **realistic session**: a person doing several normal things, with the risky behaviour checked *along the way*. "Delete an invoice" alone is a unit test wearing a journey costume; "a customer creates three invoices, sends one, deletes a draft, and the sent one is still there and still theirs" finds the bugs that only appear when state builds up. Each journey states its **outcome** (the change in the person's world), its **persona**, and a one-line **success** a manager can read. `uj explain journeys/` prints every journey as that story, with no code.

## What uj also does

Checks your OpenAPI document for completeness and compares two versions of it (`uj contract`), scores any test's output honestly (`uj verdict`), shows which risks your journeys cover (`uj coverage`), and runs suites in CI with machine-readable results. SOPs 15–17 cover these.

## In one sentence

Write what a real user does as a readable file in your repo; uj runs it against your service, cleans up after itself, and gives a verdict you can trust, with "broken product" and "broken environment" kept apart.

**Next:** SOP 02, day zero: Acme tests `invoicer`.
