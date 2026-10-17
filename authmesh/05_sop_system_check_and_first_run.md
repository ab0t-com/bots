# 05 · Check it, preview it, run it

**What this is for.** Turning your `config/` into a live, working service on the mesh: your org, your admin account and service key, your sign-in client, your login page, the org your users land in, and a proof that a brand-new user can sign up and get the right permissions.

**Before you start.** SOP 04 done and `authsetup --config-dir ./config validate` is clean. `authsetup version` says 0.5.24 or later (SOP 03). You are in your service folder. You know which environment you want: build on `dev` first, prod later with the same files.

## Steps

**1. Preview. Nothing changes.**
```sh
authsetup --env dev --config-dir ./config up --dry-run
```
`up` reads the live server and shows the plan in plain words, grouped as **your app** (`invoicer`), **your users** (`invoicer-users`) and **your partners** (`invoicer-api-consumers`), under a banner `Plan for invoicer — env: dev (https://auth.dev.ab0t.com)`. `+` lines are things it will create or change; `~` lines are settings it re-sends from your files (only shown when your config files changed since the last `up`, or on the first one); "set up after your app exists" is normal on a first run. It ends `--dry-run: nothing was changed.`

**Before anything is created, the name is checked.** Your `registration.service` (`invoicer`) is a name in one shared permission registry. Step 01 reads that registry first, in the preview too. If another organization already owns the name, the preview stops (exit `1`) with `permission schema name "invoicer" is taken — …` and nothing is created; see *If it goes wrong*. If the registry cannot be read, it says `could not read the public permission registry (…) — the schema name is checked again once your service org exists` and carries on.

**Choose your admin's email before the first apply.** Step 01 creates one admin account for your service. It owns your service org, and authsetup signs in as it from then on. Its password is generated and kept in `~/.authmesh/invoicer/invoicer.<env>.json`, so nobody types it. Unless you set `ADMIN_EMAIL`, the address is `invoicer-admin@` plus the domain of `service.maintainer`, or `invoicer-admin@example.com` when `permissions.json` has no `maintainer` (as after `init --publish`). The preview then says `(set ADMIN_EMAIL to use a real mailbox you control)`.
```sh
ADMIN_EMAIL=invoicer-admin@acme.example authsetup --env dev --config-dir ./config up --dry-run
ADMIN_EMAIL=invoicer-admin@acme.example authsetup --env dev --config-dir ./config up
```
Use a real mailbox that your team reads. The auth service mails this address: above all the **password-reset link**, which is how you get the admin back if its credentials file is lost or the password stops working (SOP 16), and also notices such as a sign-in from a new device. `example.com` is reserved and never receives mail, so with the default address none of this mail arrives and you cannot reset a lost admin password yourself. Addresses ending in `.test`, `.local`, `.localhost` or `.invalid` are refused at sign-up. An email address belongs to one account per environment, so each service needs its own admin address (`ops+invoicer@acme.example` works); a reused one stops step 01 with `admin … already exists`. authsetup reads `ADMIN_EMAIL` only on the first run against an environment. After that it uses the saved file, and changing the variable changes nothing.

**2. Say yes, apply.**
```sh
authsetup --env dev --config-dir ./config up
```
The same plan, then `Apply N change(s) to dev?` (on a first run `…, then set up the rest?`); nothing changes until you answer yes (the default is no; `OK — nothing was changed.` otherwise). It runs steps 01 to 08 in order and stops at the first failure. When it finishes: `✓ Done — invoicer on dev now matches your config.` Re-running is always safe: when everything matches it says `✓ invoicer on dev already matches your config — nothing to change.` and stops.

No `--env` and no `use-env` choice? `up` asks which environment once (default `dev`) and never guesses prod. In a script (or from an assistant, whose shell is not a terminal): `authsetup --env dev up --yes`; without `--yes` it says `Not applied: this is not a terminal, so there is nobody to answer the question.`

**3. Expert path (the numbered pipeline).** For support, CI, and running one step:
```sh
authsetup --env dev --config-dir ./config --dry-run run       # the full step-by-step plan; lines starting `→ would:` are the changes
authsetup --env dev --config-dir ./config run                 # apply all 01–08
authsetup --env dev --config-dir ./config run 04              # or a slice
```

**4. Prove it.**
```sh
authsetup --env dev --config-dir ./config run 06    # signs up a throwaway user, checks their permissions, removes the user
authsetup --env dev --config-dir ./config status    # what is live vs what your config says
```

**5. Later, the same for prod.** Same files, different flag. The plan banner says `⚠ PRODUCTION — your live customers use this environment`; after your yes you are asked to type `prod` the first time. Run it in your own terminal.
```sh
authsetup --env prod --config-dir ./config up --dry-run
authsetup --env prod --config-dir ./config up
```
Never copy credential files between environments; prod gets its own by running against prod.

## What each step creates

| step | what it does | config it reads | credentials it writes (`~/.authmesh/invoicer/`) |
|---|---|---|---|
| 01 | checks the name is free, then your **service org** `invoicer`, its admin account (`invoicer-admin@acme.example` unless you set `ADMIN_EMAIL`), the permission list in the registry (owned by your service org), and your **service key** `invoicer-internal` | `permissions.json` | `invoicer.dev.json` (admin email + password, org id, `api_key.id` + `api_key.key`) |
| 02 | the sign-in (OAuth) client on the service org, for your own admin surface | `oauth-client.json` | `oauth-client.dev.json` |
| 03 | your branded login page settings on the service org | `hosted-login.json` | — |
| 04 | the **`invoicer-users` org** where customers land, its **default team** holding every `default_grant` permission, the org structure, the login settings (with your default role and team filled in), and the **customer sign-in client**; it checks the permission schema **last**, as your service org, so a schema problem never stops your sign-in client from being updated | `permissions.json`, `hosted-login.json`, `oauth-client.json` | `end-users-org.dev.json` (org id, slug, default team id, `hosted_login_url`), `end-users-oauth-client.dev.json` (the `client_id` your frontend uses) |
| 05 | read-only verification of all of the above, including that your service key really holds the permissions you declared | all | — |
| 06 | registers a throwaway `setup-go-test-…` user through the real sign-up flow, asserts they hold every `default_grant` permission, checks the token audience, then **removes that user** (pass or fail) | `end-users-org.dev.json` | — |
| 07 | registers *you* as a consumer of other services you declared in `config/clients.d/` (SOP 11); nothing to do if that folder is empty | `clients.d/*.json` | `<provider>-consumer.dev.json` |
| 08 | opens your API to other services: the **`invoicer-api-consumers` org**, tier teams, sign-up settings, and a listing in the mesh directory (SOP 12); it checks the permission schema first, as your service org | `api-consumers.json` (optional) | `api-consumers.dev.json` |

Only your **service org** ever registers your permission schema; steps 04 and 08 only check it (`… already registered and owned by service org <id> — admin surface — nothing to do`) and re-register it as the service org if it is missing or out of date.

Also in that folder: `journal/run-<timestamp>.jsonl` (every request and response, secrets redacted; keep it for audits), `.setup-go.lock` while a run is in progress, and `.prod-ack` after your first confirmed prod change. Files are mode 0600 and named `<thing>.<env>.json`, so `dev` and `prod` never collide.

## What you'll see

At each identity or org switch: `· acting as invoicer-admin@acme.example in your service org invoicer (<id>)`. Per step: `✓` lines for things that already matched or were changed, `~ re-sent: …  (authsetup cannot compare this setting, so it sends it again — same values)` for settings it cannot diff, and in a preview `→ would:` lines. A first preview also shows `· deferred — it needs your service org, which step 01 creates; …` for later steps; that is information, not a failure, and a preview never prints `✗` for it.

The run summary lists each step as `ok`, `FAILED`, `deferred`, `needs you` or `not reached`, then one line:
- preview: `N change(s) planned — nothing was mutated` (N equals the `would:` lines above it);
- apply: `N changed · M re-sent`, or `no changes were needed — server state already matches config` (with the re-sent count when there were any);
- a failure: `✗ run failed at step 02 (<step name>)` and a NEXT line `fix the failure above, then resume with: authsetup --env dev --config-dir ./config run 02 03 …`.

After a full `run`, NEXT points at `status`, `settings --env-file .env` and `login-url --check`, each with your `--env`. Exit codes: `0` converged, `1` hard failure, `3` drift (`status`), `4` something needs a human.

Step 04 prints `hosted login page OK: https://auth.dev.ab0t.com/login/invoicer-users`. That URL is your customers' front door. Step 06 prints `token audience = "invoicer" (matches service.audience)` and `removed test user setup-go-test-… (the check is done; nothing is left behind)`. If it instead warns the audience is `SELF:<org id>`, your org was created by an older tool without an audience; see SOP 16.

## If it goes wrong

- `permission schema name "invoicer" is taken — it is registered to another organization (org <id>), so this new setup cannot use it (nothing was created).` Another service already uses that name. Choose a different `registration.service` in `permissions.json` (and start your permission ids with it), `validate`, preview again. If that org is an **earlier setup of this same service** (another machine, an old folder), point at its credentials with `--creds-dir <dir>` instead.
- `permission schema "invoicer" is already registered with no owner recorded …` An old registry entry nobody may change. If it is yours, `--creds-dir` the old setup and ask the auth team (platform-team@ab0t.com) to record your service org as its owner; otherwise choose a different name. Re-running will not help. SOP 16 lists every variant.
- `HTTP 403 … the key for service admin … needs PRIVILEGED permissions …` on step 01. The key would carry a permission the auth service treats as cross-customer. The message gives the self-serve fix first: mark the cross-customer permissions `"scope": "platform"` (SOP 04) and run again; your own admin then grants them. For a service that has not declared `scope`: ask the platform team to run the printed `curl … /admin/privileged-grants` call, or, if you are the platform admin, export `AUTHSETUP_PLATFORM_ADMIN_TOKEN` and re-run step 01.
- `admin invoicer-admin@acme.example already exists — this service looks already set up. …` You have credentials somewhere else (another machine, or the old bash kit). Point at them with `--creds-dir`, run `authsetup migrate` from the old folder (SOP 15), or, for a genuinely new service, change `service.id` or set `ADMIN_EMAIL`.
- `a service org with slug "invoicer" already exists — … Not creating a duplicate` — same cause; same fixes. The tool never creates a duplicate.
- `the saved admin credentials (admin …, file …) no longer sign in to …` — stale credentials; the message lists three causes. SOP 16, *Recovery*.
- `the auth server at <url> advertises its client-management endpoint on <other origin> — a different origin, so authsetup sent nothing there …` on step 02 or 04. A safety stop: the tool sends credentials only to the auth URL you chose. SOP 16.
- `rate limited by the auth service (~5 requests/min)` — a full run makes many calls; the tool backs off and retries. If it still gives up, wait a minute and run again; it resumes where it stopped.
- `credentials dir is inside a git repository and NOT gitignored` / `creds dir … is inside a git repo and not gitignored; re-run with --write-gitignore (recommended) …` — your `--creds-dir` points into a repo. Re-run with `--write-gitignore`, or let it default to `~/.authmesh/invoicer/`.
- `another authsetup run (pid 1234) is working on this setup right now (lock …) — wait for it to finish` — wait. `a stale lock from … was left at … — it is safe to remove that file, then run again` — remove only that file.
- Exit `4`, a step marked `needs you` — usually `redirect_uris` changed on a client whose management token was never saved. The rest converged. SOP 13 explains the three options it prints.
- `test user is missing default_grant permissions …` on step 06 — the sign-up-to-team flow is broken. Re-run step 04; if it persists, set `end_users.default_role` to `"member"` and re-run 04.
- `could not remove test user setup-go-test-… from end-users org invoicer-users: … — remove it from that org's members` — a warning only; the check itself passed or failed on its own. Remove that member later.
- `Could not work out the plan — here is what the checks said:` from `up` — the preview itself failed; the step detail is printed under it. Read it as above.

## Coming

- **A machine-readable result for `up` and `run`** (`--json`). *Today:* branch on the exit code (`0`/`1`/`4`), and on the presence of `nothing to do` if you must; never on exact wording.

## Next

SOP 06, wire it into your app: `authsetup --env dev settings --env-file .env` and `authsetup --env dev snippet login`.
