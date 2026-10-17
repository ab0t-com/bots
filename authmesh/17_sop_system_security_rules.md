# 17 · Security rules

**What this is for.** The short list of things that keep your service, your customers and your own keys safe on the mesh. Each rule says what the tool already enforces (as of `authsetup` 0.5.24) and what is on you.

**Before you start.** Read SOP 01 (the scope model) once. Everything below is a consequence of it plus ordinary secrets hygiene.

## The rules

**1. Never make a `platform` permission a default.**
A permission that reaches across customers is never `default_grant: true`, never in the default role, never in a workspace's `default_team_permissions`, never in the default consumer tier. *Enforced:* `validate` refuses `privileged permission "…" must not be default_grant:true (cross-tenant is invite/explicit-only)` and `api-consumers: tier "…" is default:true (auto-join) and grants privileged perm …`; with `scope` declared it also refuses a `platform` or `risk_level` `high`/`critical` permission in `default_grant`, a default role or `default_team_permissions`, and a reach-word name not marked `platform`.

**2. The service that defines a permission decides who gets it.**
Only your own service org's admins hand out your `platform` permissions, one person, one permission, with a reason, logged: `authsetup grant-platform … --reason "…"`, reviewed with `authsetup platform-holders`, taken back with `revoke-platform` (which also revokes that person's keys in that org that carry it). Your customers' admins may hand out your `org` permissions inside their own org and nothing more. Never ask the platform admin to grant a customer anything; if a customer needs cross-customer reach, they are a partner service and belong in a non-default, `privileged_ack: true` tier (SOP 12).

**3. Never test against prod.**
Build on `--env dev` or `--env local`; promote by running the same config against `--env prod`. The tool defaults to prod (except `up`, which asks), so write `--env` on every command, check that every NEXT line you copy names your environment, and set `authsetup use-env dev` on development machines. The first prod change asks you to type `prod`; treat that prompt as a review, not a formality. Each prod `up`/`run` signs up one throwaway test user in your users org and removes it again (step 06); if a removal warning appears, remove that member by hand.

**4. Credentials go only to the auth URL you chose.**
*Enforced (0.5.24):* `authsetup` sends a request, and so any password, token or registration secret, only to the same scheme, host and port as the auth URL you gave it (`--env` or `--base-url`). If an auth server advertises its client-management endpoint on another origin, or redirects a request to one, the tool sends nothing there and the step fails with `the auth server at <your url> advertises its client-management endpoint on <other origin> — a different origin, so authsetup sent nothing there …` (or `… redirected <request> to <other origin> …`). That is the safety working. The fix belongs on the server (its public URL setting, `BASE_URL`, or its proxy). Switch your `--base-url` to the advertised origin only when you know it is the real address of *your* auth service; never to an origin you do not recognise, and never to production from a local or dev setup. Before 0.5.24 the tool followed such URLs and could send a local or dev credential to another host: upgrade (SOP 15).

**5. Secrets stay in `~/.authmesh/` and your secrets manager.**
- Credential files are `0600`, outside any repository, per environment. The tool refuses to write them into an un-ignored repo path.
- The service key and consumer keys are **never printed** by the tool. `authsetup --env <env> settings` shows them masked; `settings --env-file .env` writes the value into a `0600` file without showing it. Never into chat, a ticket, a log line, or a frontend bundle. The `client_id` is public; the key is not.
- Never copy credential files between environments.
- Never delete `~/.authmesh/<service>/`; it holds every environment, including prod. Move one file aside at most (even after `destroy`, whose NEXT talks about the directory).
- Never commit a real `service_account_password` in `clients.d/<provider>.json`; leave it empty and the tool generates one and keeps it in the credentials folder.
- Journals (`journal/*.jsonl`) are redacted and are your audit trail; keep them.
- `doctor` does not sign in by default, so running it often as a health probe cannot lock out your admin with a stale password. Use `doctor --strict` deliberately.

**6. Verify every request, with your audience.**
Your backend asks the auth service on every call (or verifies locally with the SDK) and always checks your audience (`invoicer`) on user tokens. Without it, a token minted for another service validates against yours. Fail closed: an auth-service error is a `503`, never an allow. After the permission check, check that the resource belongs to the caller: compare its `org_id` with the caller's, or, in a shared `flat` space where every customer has the same `org_id`, compare its owner's `user_id` (SOP 09). The SDKs cache answers for seconds by default (Go v0.12.0+, Python 0.1.4+); use the fresh-validation option on routes where a revocation must bite at once (SOP 06).

**7. Keys are fixed, so mint narrowly and rotate.**
A key holds exactly the permissions it was minted with. Mint the least you need (a consumer takes the default tier unless it truly needs more), rotate on your policy's cadence (SOP 14), and revoke before you investigate when something leaks.

**8. Users get in only through your org's door.**
Sign-up goes through `/login/invoicer-users` (or the org-scoped `/organizations/invoicer-users/auth/register`), so new users join your users org and its default team. The global sign-up creates a user with no org and no permissions. Prefer `invitation_only: true` for products that are not open to the public.

**9. Separate your admin surface from your customers'.**
Two sign-in clients exist for a reason: `oauth-client.<env>.json` (service org, your staff) and `end-users-oauth-client.<env>.json` (users org, your customers). Do not reuse the customer client for internal tools.

**10. Never skip the gates in automation.**
`--skip-validate`, `--unsafe-creds-in-repo`, `AUTHSETUP_CONFIRM_PROD=1`, `up --yes`, `disconnect --yes` and `grant-platform --yes` exist for CI. Each one needs a human's explicit decision written down next to the pipeline that uses it. Scripts branch on exit codes, never on the wording of human output.

**11. Prefer the CLI; use the API only where an SOP's "Today" says so.**
Hand-rolled calls bypass the reconcile model, the dry-run, the journal and the guards. When you must call the API (invites, ordinary grants, key deletion, until their commands exist), do it with the admin of the org that owns the object, and run `authsetup status` afterwards so config and server still agree.

## What the tool enforces for you today

`validate` gates every command on a clean config. Prod mutations need an explicit target plus a one-time typed confirmation, and `</dev/null` counts as "no terminal". Credentials cannot land in an un-ignored repo, and are sent only to the auth URL you chose. A key mint may not carry permissions the account does not hold (the server refuses with `403`). Consumer tiers that carry a privileged permission must be non-default and acknowledged. Derived tiers never include a privileged permission. `platform` grants need a reason and are logged. `disconnect` requires typing the provider's name. `destroy` requires typing the service id. Secrets never appear in output. The permission schema can only be registered or changed by the org that owns it, and a taken name stops a first run before anything is created.

## Coming

- **Automatic revocation of everything the previous owner handed out** if a service changes owner. *Today:* manual.
- **`authsetup login`** so the tool acts as a named person rather than a credentials folder. *Today:* SOP 03.

## Next

Back to SOP 00 (the index) to find the job you came for.
