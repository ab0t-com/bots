# 16 · Troubleshooting and recovery

**What this is for.** Something failed, or your users are getting `403`s, or a run says things you do not understand. This SOP lists the messages you will actually see, in the tool's own words (as printed by `authsetup` 0.5.24), what each means, and the fix. It ends with the recovery situations: a wiped local database, stale credentials, a stuck lock, and the wrong environment.

**Before you start.** `authsetup version` (an older binary prints older wording; SOP 15 step A). Then three read-only commands tell you most of the story; run them and keep the output:
```sh
authsetup --env <env> doctor            # binary · auth reachable · config · creds dir · service key capability · admin creds · connections
authsetup --env <env> status            # what is live vs config; exit 0 converged, 3 drift
authsetup --env <env> whois <id>        # which object is this client_id / org_id / key id, and which file drives it
```
Every server exchange is also in `~/.authmesh/invoicer/journal/run-<timestamp>.jsonl`, secrets redacted.

**Read the exit code first, then the whole message.** `0` converged · `1` failed (including an unknown command or step) · `2` unknown flag · `3` drift found by `status` · `4` needs a human. Each `✗` line says what happened and what to do; the `NEXT —` block gives the exact next command (check it names your `--env`). Do not grep for older phrases such as `HTTP 403`: 0.5.24 reworded many of them.

## Messages, meanings, fixes

**Environment and safety**

| you see | it means | do |
|---|---|---|
| `refusing to mutate PRODUCTION (…) without an explicit target — pass --env dev (or --env <name>), …` | no `--env`; the default is prod | add `--env dev` (or `--env prod` deliberately) |
| `refusing to mutate PRODUCTION (…) on a non-interactive terminal without confirmation — set AUTHSETUP_CONFIRM_PROD=1 (automation) to proceed` | a script, a pipe or `</dev/null` hit prod | run it in a terminal, or `AUTHSETUP_CONFIRM_PROD=1` if intended |
| ``up needs a chosen environment and never guesses production — pass --env dev (or --env prod), or run `authsetup use-env dev` once`` | `up` in a script with nothing chosen | add `--env` |
| `not applied — this is not a terminal; review the plan above and re-run with --yes to apply` | `up` could not ask you | read the plan; re-run with `--yes` |
| `auth service unreachable at <url>: …` | wrong env/URL, or the service is down | `authsetup --env <env> env`; dev is `https://auth.dev.ab0t.com` |
| `environment "dev" resolves to … but an explicit URL … was also given — they must agree (drop one)` | `--env` and `--base-url` / `AUTH_SERVICE_URL` disagree | pass one |
| `creds dir … is inside a git repo and not gitignored; re-run with --write-gitignore (recommended) or --unsafe-creds-in-repo, …` | your credentials would land in a repository | `--write-gitignore`, or default to `~/.authmesh/` |
| ``unknown flag --jsn — did you mean --json?  (see `authsetup status --help`)`` (exit `2`) | a typo | use the suggested flag |
| `✗ unknown command "…" — try: init, up, …` / `unknown step "10" (valid: 01..09)` (exit `1`) | a typo | `authsetup --help` |

**Credentials go only to your auth URL (new in 0.5.24)**

| you see | it means | do |
|---|---|---|
| `the auth server at <your url> advertises its client-management endpoint on <other origin> — a different origin, so authsetup sent nothing there (it sends credentials only to <your url>); check that auth server's BASE_URL (or its proxy) setting` | while updating a sign-in client (steps 02/04, `obo-actor --rotate/--disable`), the server pointed authsetup at another scheme, host or port. Nothing was sent; the step fails (exit `1`) | whoever runs that auth service fixes its public URL setting (`BASE_URL`). If the advertised origin *is* the right address of your auth service (you used an alias, `http` vs `https`, or a different port), use it as your `--base-url` and run again. Never "fix" it by pointing at an origin you do not recognise |
| `the auth server at <origin> redirected <METHOD /path> to <other origin> — …` | the server or a proxy redirected a request elsewhere; authsetup does not follow a redirect to another origin (it would carry your password or token) | same: fix the server/proxy, or use the right `--base-url` |

To check a server up front: `curl -s <auth URL>/.well-known/oauth-authorization-server | jq -r .registration_endpoint` must start with your auth URL.

**Config (`validate`)** — one line per problem, no server touched (`— not contacted: validate is local-only`). SOP 04 lists them. The ones that stop a run most often: `registration.service "my-invoicer" will be REJECTED by the auth service registry (…). Try "myinvoicer".`, `no permission has default_grant:true — new users would have no access`, `<file>: invalid JSON at line L, column C — …`, and in declared mode `permission "…" reaches across customers by its name (…) — set "scope": "platform" on it, …`. With no config at all: `permissions.json is required: …`, then a NEXT offering `authsetup init --publish` or `--config-dir <dir>`.

**The permission schema name (step 01, and checked again in 04 and 08)**

Your `registration.service` is a name in one shared registry; only the org that owns it may change it. From 0.5.24 step 01 checks it **before creating anything** (in a preview too), and only your service org ever registers it.

| you see | it means | do |
|---|---|---|
| `permission schema name "invoicer" is taken — it is registered to another organization (org <id>), not to your service org invoicer (<id>).` (on a first run: `…, so this new setup cannot use it (nothing was created).`) | another organization owns the name | choose a different `registration.service` in `permissions.json` (and start your permission ids with it), `validate`, preview again; or, if org `<id>` is an **earlier setup of this same service**, point at that setup's credentials with `--creds-dir <dir>` |
| `permission schema name "invoicer" is taken — it is reserved by the auth platform, …` | a name the platform uses | a different `registration.service` |
| `permission schema "invoicer" is registered with no owner recorded (an entry from before ownership was tracked), so the auth service lets nobody change it. … ask the auth team to record your service org invoicer (<id>) as its owner. Re-running authsetup will not help.` | an old registry entry; nobody may change it until its owner is recorded | ask the auth team (platform-team@ab0t.com) with the service name, environment and your service org id. On a first run the message instead suggests `--creds-dir` to an older setup, or a new name |
| `the auth service refused to register permission schema "invoicer" for your service org …: either another organization owns that name, or it has no owner recorded — the server did not say which.` | an older auth service did not say which case | try both fixes above: a new name, or ask the auth team |
| `could not read the public permission registry (…) — the schema name is checked again once your service org exists` (warning) | the registry read failed; "unknown", not "taken" | nothing; the run goes on and checks again |
| ``… — auth refused the scope declaration: every permission whose name reaches across customers … must be "scope": "platform" … Run `authsetup validate` to see which line`` | the auth service refused your `scope` declaration (`400`) | `validate`, fix the line it names |
| `permission schema "invoicer" already registered and owned by service org <id> — admin surface — nothing to do` | all good | — |

Scripts: these are all exit `1`. Tell them apart by `is taken` / `no owner recorded`; anything else needs a human.

**Step 01, other**

| you see | it means | do |
|---|---|---|
| `admin <email> already exists — this service looks already set up. …` | credentials exist elsewhere, or the bash kit made them | `--creds-dir <there>`, `authsetup migrate` (SOP 15), or a new `service.id` / `ADMIN_EMAIL` |
| `a service org with slug "invoicer" already exists — … Not creating a duplicate` | same | same; the tool never duplicates |
| `could not create service org with slug "…" (server: HTTP 400: …) — …` | the slug is taken by someone else, or rejected | if yours, `migrate` / `--creds-dir`; else change `service.id` |
| `the saved admin credentials (admin <email>, file <path>) no longer sign in to <url> (…) — likely causes: (1) … reset …; (2) … another environment's credentials, or the wrong --creds-dir …; (3) the admin password was changed …` | the saved admin cannot sign in here | see *Recovery*: (1) move **that one file** aside and run again (local/dev resets); (2) `authsetup info` and the right `--env`/`--creds-dir`; (3) put the new password in `admin.password` of that file |
| `cached org <id> not found on server: …` | the org in your credentials file is gone on this server | wrong environment, or a reset; *Recovery* |
| `HTTP 403: … — the key for service admin … needs PRIVILEGED permissions […]. Self-serve fix: in permissions.json mark each permission that reaches across customers "scope": "platform" …` | the key would carry permissions treated as cross-customer | declare `scope` (SOP 04) and run again; for an undeclared service, the printed platform-admin call or `AUTHSETUP_PLATFORM_ADMIN_TOKEN` (SOP 05) |
| `owner sanction of […] for … refused by auth (…) — continuing; the mint below decides` (warning) | the auth service did not accept your admin's own grant (older auth, or the schema is not yours) | read the next line; if the mint then fails, as above |
| `rate limited by the auth service (~5 requests/min); backed off but still capped — pause ~60s and re-run …` | too many calls in a minute | wait ~60 s, run again; it resumes |

**Steps 02–04 (sign-in clients, login page, users org)**

| you see | it means | do |
|---|---|---|
| ``HTTP 400: invalid_redirect_uri — Invalid redirect URI: notaurl — fix redirect_uris in ./config/oauth-client.json (`authsetup validate` checks their format)`` | the server refused a redirect URI | fix it in `oauth-client.json`; `validate` warns about these before you run |
| `redirect_uris on <client> differ from ./config/oauth-client.json, and authsetup cannot update them: the client's management credentials (RFC 7592) are not in <file>` + `+`/`-` lines + `what you can do: (1) restore … (2) … new client_name … (3) ask the auth team …`; summary `needs you`, exit `4` | the tool cannot update that client | SOP 13 step 4, in that order |
| `redirect_uris 20/20 — AT the limit; …` | server cap | remove one first |
| `end-users org "invoicer-users" already exists but is not visible to this admin (orphaned sub-org / membership gap from a partial run) — …` | orphan from a half-run | do not create a duplicate; ask the platform team to repair membership, re-run |
| `HTTP 400: … Login config validation failed` | an `accept_invite_*` origin is not in the allow-list | SOP 07 |
| `registration.default_landing="workspace" but org_structure.pattern="flat"` | a warning | set the pattern, or use `"parent"` |
| `hosted login page … not OK yet: …` | page not answering | re-run step 04; check the service health |
| step 04 fails on the permission schema | 0.5.24 checks the schema **last** in step 04, so your users' sign-in settings and client were already updated | fix the schema message (table above), run again |

**Steps 05–06 and your users' `403`s**

| you see | it means | do |
|---|---|---|
| `service API key <id> exists but holds N of M declared permissions (UNDER-PERMISSIONED)` / `doctor`: `service key ◐ … UNDER-PERMISSIONED; missing: … → re-mint` | the key holds fewer permissions than config | re-mint (SOP 14) |
| `default team carries all default_grant perms (missing: …): drift — run step 04 to sync` | team lost a permission | `run 04` (or `up`) |
| `test user is missing default_grant permissions: … (registration→team flow broken)` | sign-up did not join the team | `run 04`; if it persists set `end_users.default_role: "member"` and `run 04` |
| `could not remove test user setup-go-test-… from end-users org …: … — remove it from that org's members` (warning) | step 06's cleanup failed; the check itself is unaffected | remove that member later |
| `token audience is "SELF:<org id>", not "invoicer" — this org was created WITHOUT a service_audience …` | the org was created without an audience by an older tool; **immutable** | a replacement users org with the audience is required; contact the platform team before doing anything |
| your API returns `401 Audience doesn't match` | backend audience ≠ the org's | same as above, or fix `AB0T_AUTH_AUDIENCE` / `WithExpectedJWTAudience` (SOP 06) |
| a partner's mesh key is refused by your Go service | `WithExpectedAudience` also applies to API keys, which carry no audience | use `WithExpectedJWTAudience` (auth-sdk-go v0.12.1, SOP 06) |
| a user `403`s on a permission you just added | registry cache, ~5 min | wait, or have them log in again |
| a user `403`s on a default permission | they joined via the global sign-up, or are in another org | sign-up must go through `/login/invoicer-users` |
| an API key `403`s where a user token works | keys are fixed at mint; users are computed | re-mint the key |
| a revoked key or grant still works for a few seconds | SDK caches (Go v0.12.0+, Python 0.1.4+): up to 60 s for keys, 15 s for permissions | expected; `fresh` / `WithFreshValidation` on sensitive routes (SOP 06) |
| `HTTP 422: <detail>` from any step | the server rejected a field (bad slug, bad email, malformed body) | read the detail; `validate` catches most of these locally |

**Consumers (`providers`, `connect`, `run 07`, `run 08`)**

| you see | it means | do |
|---|---|---|
| `provider "x" did not grant every permission tier "y" requests — the default tier is zero-touch; …` | you asked for more than the tier gives | default tier, then ask the provider (SOP 11) |
| `consumer account … already exists but the stored password did not authenticate — pass --email with a fresh address …` | created from another machine | use that machine's creds, or `--email` a fresh address |
| `tier "x" not offered — available: …` | wrong name | pick a listed one |
| `this auth service has no mesh provider directory yet (GET /mesh/providers → 404) — …` | not deployed on this env | another `--env` |
| `closed — invitation only` on a provider card; `provider "x" has self-serve registration disabled — contact the provider for an invitation` | that provider's sign-up is off | ask it for an invitation |
| `# X_SERVICE_URL: not published for this environment — ask the provider for its URL` | off production, `connect` no longer guesses the provider's URL | ask the provider |
| `○ REGISTERED` in `status` with no key | orphan from an interrupted mint | re-run `connect` to adopt |
| `co-located mode needs the provider's creds file` | `run 07` without the provider's credentials | use `connect` |
| `self-serve sign-up for consumers is OFF: they need an invitation from you …` (your own step 08) | the default for your service | open it with `registration.signup_enabled: true` in `api-consumers.json` if you want (SOP 12) |

**Platform grants (`grant-platform`, `revoke-platform`, `platform-holders`)** — SOP 10 lists them: `… has not declared scope yet`, `… is an org permission`, `… is not a member of org …`, `--reason is required …`, `… refused: … the caller must be an admin of the org that OWNS …`.

**Runs and locks**

| you see | it means | do |
|---|---|---|
| `✗ run failed at step NN (<name>)` with later steps `not reached` | that step failed | fix the line above it; NEXT `resume with: authsetup --env … run NN …` |
| `· deferred — it needs your service org, which step 01 creates; …` in a preview | normal on a first preview | nothing |
| `~ re-sent: …` | a setting sent again unchanged | nothing (SOP 13) |
| `Could not work out the plan — here is what the checks said:` (`up`) | the preview failed | read the step detail under it, as above |
| `another authsetup run (pid 1234) is working on this setup right now (lock <path>) — wait for it to finish, then run again` | a second run is alive | wait |
| `a stale lock from a run that is no longer running (pid 1234) was left at <path> — it is safe to remove that file, then run again` | a crashed run left its lock | move **only** that file aside, run again |

## Recovery

**A wiped local database.** Your local auth stack lost everything (a local stack that keeps its data in memory does this on every restart), and `run` says `the saved admin credentials (admin …, file ~/.authmesh/invoicer/invoicer.local.json) no longer sign in to http://localhost:8001 …`.
```sh
mv ~/.authmesh/invoicer/invoicer.local.json ~/.authmesh/invoicer/invoicer.local.json.old
authsetup --env local --config-dir ./config up --dry-run
authsetup --env local --config-dir ./config up
```
Always `--env local`. Moving aside **only** the local file lets the run bootstrap a fresh local admin. **Never delete `~/.authmesh/invoicer/`**: it holds `invoicer.prod.json` and every other environment's keys. If the preview then says the schema name `is taken — it is registered to another organization (org <id>)`, the server was not reset after all (that org is your old local setup): move the file back and follow cause (2) or (3) of the message instead.

**Stale credentials on dev or prod.** Someone reset the admin password or the org was removed. Reset the password through the auth service for the admin email, update `admin.password` in `invoicer.<env>.json`, then `authsetup --env <env> doctor --strict` to prove the sign-in, then run again. (Plain `doctor` only reads the file: `✓ saved credentials present (sign-in not tried)`.) If the whole folder is lost: recover the admin via password reset, re-register OAuth clients under a new `client_name` (their management tokens are gone), then `up` reconciles around the recovered identity.

**Wrong environment applied.** Nothing is shared between environments except your config. Run against the right `--env`; clean up the wrong environment's orgs deliberately (`destroy` on that env, SOP 14, or the auth API).

**A pasted NEXT line went to the wrong place.** From 0.5.24 NEXT lines carry your `--env`/`--base-url`; when nothing chose the target, they leave it out on purpose, and the production guard still asks. Re-run with the right `--env`; if something was changed on the wrong environment, see above.

## What you'll see

`doctor` prints a `✓ / ◐ / ⨯` line per check with one suggested next step each, and exits `0` when the auth service is reachable and config is valid. Its `admin sign-in` row is information only. `status --verify` promotes `WIRED` connections to `LIVE` or marks them `FAILED` if a key was revoked server-side.

## If it goes wrong

Collect `doctor --json`, `status --json`, the failing command's full output, and the latest `journal/*.jsonl`, and send them to the platform team (`platform-team@ab0t.com`). Secrets are already redacted in the journal; never paste a credentials file.

## Coming

- **`doctor` reading a `403` for you**: paste a key id or user id and get "this key lacks X; minted <date>; re-mint with …". *Today:* `whois <id>` plus the tables above.
- **A guided repair for the orphaned users org and the `SELF:` audience**, which today need the platform team.
- **A self-serve fix for a schema with no owner recorded.** *Today:* the auth team.
- **`authsetup unlock`.** *Today:* the lock message says stale or alive; move the one file aside when it says stale.

## Next

SOP 17, the security rules. Or back to SOP 13 once the run is green.
