# 10 · Your team and platform permissions

**What this is for.** Acme's own people: bringing a colleague into the `invoicer` service org, giving them ordinary (`org`) permissions, and, for the very few who need it, a **platform** permission such as `invoicer.support.read_all` that reaches across every customer. Platform grants are CLI commands run by your own admin; inviting colleagues and ordinary grants are still API calls today.

**Before you start.** SOP 05 done on this environment. Your `permissions.json` declares `scope` (SOP 04): `grant-platform` only works for a service that has. You are in your service folder (the commands sign in as the admin step 01 created, from `~/.authmesh/invoicer/invoicer.<env>.json`). The person you grant to is already a member of the org (step 1). Your service org id: `authsetup --env dev info`.

## The rules (SOP 01, in one breath)

- Only admins of **your** service org may hand out **your** `platform` permissions: one person, one permission, with a written reason, and every grant is logged.
- A `platform` permission is never carried by a role, a team, a default, or a consumer's default tier, so nobody gets one by accident.
- Your customers' admins may hand out your `org` permissions, including `invoicer.admin`, inside their own org only. They can never grant a `platform` one, not even to themselves.
- Auth's platform admin can override anything; they are never a step in your onboarding.

## Steps

**1. Bring a colleague into the service org.** (API today; see *Coming*.)
Sign in as the service admin, scoped to the service org, then invite:
```
POST https://auth.dev.ab0t.com/auth/login
{ "email": "invoicer-admin@acme.example", "password": "<admin.password from invoicer.dev.json — never paste it into chat>", "org_id": "<service org id>" }
→ access_token

POST https://auth.dev.ab0t.com/organizations/<service org id>/invite
Authorization: Bearer <access_token>
{ "email": "dana@acme.example", "role": "admin" }        # or "member"
```
Dana accepts from the email link and is now an admin (or member) of `invoicer`.

**2. Give a colleague an ordinary (`org`) permission.**
Either put them in a team that carries it, or grant directly:
```
POST https://auth.dev.ab0t.com/permissions/grant?user_id=<dana id>&org_id=<service org id>&permission=invoicer.write.invoices
Authorization: Bearer <access_token>
```
`POST /permissions/revoke` with the same three parameters takes it back. A `422` means a parameter is missing or the permission id is not one your service registered.

**3. Give a colleague a `platform` permission. Preview first.**
```sh
authsetup --env dev grant-platform dana@acme.example invoicer.support.read_all --reason "Tier-2 support rota, Q4" --dry-run
authsetup --env dev grant-platform dana@acme.example invoicer.support.read_all --reason "Tier-2 support rota, Q4"
```
It shows `[env dev] grant platform permission invoicer.support.read_all to dana@acme.example (user …) in org …` and the reason, asks `y/N`, then grants it through the auth service as your service admin. The grant applies in your service org by default; `--org <sub-org id>` targets one of its sub-orgs. In a script or from an assistant (not a terminal) add `--yes` after a human said yes.

**4. Take it back.**
```sh
authsetup --env dev revoke-platform dana@acme.example invoicer.support.read_all --reason "left the rota" --dry-run
authsetup --env dev revoke-platform dana@acme.example invoicer.support.read_all --reason "left the rota"
```
The auth service removes the grant in that org **and revokes every API key of Dana's in that org that carries the permission**; the revoked key ids are printed.

**5. Review who holds what.**
```sh
authsetup --env dev platform-holders
```
One row per person × permission × org, with when, who granted it and why, including the gateway permissions an in-house `run 07` sanctioned for consumers. `--json` for scripts.

## What you'll see

`grant-platform`: `✓ [env dev] granted [invoicer.support.read_all] to dana@acme.example in org <id> — held now: […]`. `revoke-platform`: `✓ [env dev] revoked […] from dana@acme.example in org <id> — keys revoked: […] — held now: […]`. `platform-holders`: `[env dev] platform permission holders of invoicer (N)` and one line each. Dana sees a new grant after a fresh login; an `org` grant resolves within about five minutes or on a fresh login. Teams carry `org` permissions only; a `platform` one put on a team is stripped by the server.

## If it goes wrong

- ``invoicer has not declared scope yet — add "scope": "platform" to the permissions that reach across customers in permissions.json, then `authsetup run 01` `` — do that (`validate`, `up`), then grant.
- ``"invoicer.write.invoices" is an org permission — grant it with a role or `/permissions/grant` …`` — it is not a platform permission; use step 2.
- `dana@acme.example is not a member of org <id> — invite them first (POST /organizations/<id>/invite), then re-run` — step 1 first.
- `--reason is required: every platform grant is logged with why …` — add `--reason "…"`.
- `grant-platform is a logged security change — pass --yes (automation) or run on a TTY to confirm; nothing was changed` — no terminal to ask on; add `--yes` once a human has agreed.
- `[env dev] grant-platform refused: … — the caller must be an admin of the org that OWNS invoicer, …` — your service org does not own the permission schema on this environment (check `authsetup --env dev run 05`), or `--org` is outside your service's tree. If step 01 said the name `is taken` or has `no owner recorded`, fix that first (SOP 16).
- ``no service credentials for "invoicer" in this env — run `authsetup run 01` first`` — wrong `--env` or not set up there yet.
- A colleague's key `authenticates yet 403s`: keys hold the permissions they were minted with; grants made later do not flow into existing keys. Re-mint (SOP 14).

## Coming

- **`authsetup invite-admin <email>`** for the service org. *Today:* step 1 by API.
- **Ordinary grants from the CLI.** *Today:* step 2 by API, or a team.
- **If your service ever changes owner**, everything the old owner handed out is revoked automatically. *Today:* manual.

## Next

SOP 11, using other services (billing, payment, and more).
