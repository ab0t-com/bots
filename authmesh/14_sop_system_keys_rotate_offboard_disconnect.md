# 14 · Keys: rotate, offboard, disconnect

**What this is for.** The secrets that let machines in: your **service key** (`invoicer-internal`, minted by step 01), the **consumer keys** you minted with `connect`, and keys your colleagues or partners hold. How to rotate them on a schedule, revoke one that leaked, and leave a provider cleanly.

**Before you start.** Know which key you mean. `authsetup --env dev info` lists your keys by id (never the value). `authsetup --env dev status` shows each connection's masked key. Have a rollout plan: a new key is only useful once your service has it.

## Facts that shape everything here

- A key's permissions are **fixed when it is minted**. Granting something to the account later does not change the key. Fewer permissions than you need means a new key.
- Revoking is **irreversible**. Any service still using the key gets `401` at once.
- Every key starts `ab0t_sk_live_…`, on every environment (dev and local too). `live` is part of the format both auth engines mint; it does **not** mean production. Which environment a key belongs to is the file it is in (`<service>.<env>.json`).
- **Your service key was revoked or deleted** (a teammate, an incident)? From 0.5.27 you do nothing by hand: `authsetup --env dev --config-dir ./config run` (or `up`) asks the auth service, and when it answers that the saved key is not valid, step 01 moves the dead key's entry to `~/.authmesh/invoicer/.archive/`, mints a new key with every declared permission and prints `your saved service key no longer works (revoked or deleted) — minted <id>; deploy it: authsetup --env dev --config-dir ./config settings --env-file .env, then restart your app (it still holds the dead key)`. Do both: until your app restarts with the new key, its calls fail. `--dry-run` shows `re-mint service key (saved key is revoked)` first. If the check itself fails (the auth service returns `5xx`, times out or is unreachable) it stops and mints nothing.
- Old keys stay valid until you revoke them, so rotation is: mint new → roll out → revoke old. No downtime.
- **Never delete `~/.authmesh/<service>/`.** It holds every environment's credentials, including prod. Move aside one file at most.

## Steps

**1. Rotate your service key** (a key that still works — a revoked one is re-minted by `run`, above). Today this is a two-step dance (see *Coming*):
1. In `~/.authmesh/invoicer/invoicer.dev.json`, set the `api_key` object to `{}` (keep everything else). Do this in an editor; do not paste the file anywhere.
2. `authsetup --env dev --config-dir ./config run 01` mints a fresh `invoicer-internal` key with every declared permission and saves it. (If the mint returns `403 … needs PRIVILEGED permissions …`, see SOP 05: declare `scope` so your own admin can grant them, or, for an undeclared service, the platform sanction.)
3. Put the new value where SOP 06 step 4 says. Deploy.
4. Revoke the old key by id, as your admin: `DELETE <auth>/api-keys/<old key id>` with `Authorization: Bearer <admin token>`, where `<auth>` is your environment's URL (`authsetup env` shows it).
5. `authsetup --env dev doctor` should report the service key holds all declared permissions.

**2. Rotate a consumer key (a provider you connected to).**
```sh
authsetup --env dev disconnect billing --as invoicer --dry-run   # what would be revoked and archived
authsetup --env dev disconnect billing --as invoicer             # type "billing" to confirm; key revoked, cred archived
authsetup --env dev connect    billing --as invoicer             # new account state, new key, same tier
```
Then re-wire `BILLING_SERVICE_API_KEY`. In automation `--yes` skips the typed confirmation; `--keep-creds` revokes but leaves the local file.

**3. Leave a provider for good.** `disconnect` alone. It revokes the key, tries to leave the org (if it cannot, the membership is left in place and is inert), and **moves** the cred file to `~/.authmesh/invoicer/.archive/` with a timestamp; nothing is deleted. The consumer account itself remains on the server (see *Coming*).

**4. A key leaked.** Revoke first, think second: `DELETE /api-keys/<id>` as the admin of the org that owns it (your service org for the service key; the provider's consumers org for a consumer key, which `disconnect` does for you). Then rotate per step 1 or 2, deploy, and read your `journal/` for the window of exposure.

**5. Offboard a colleague.** Revoke every key they hold (`GET /api-keys/` as an org admin lists them; `DELETE /api-keys/<id>`), remove their membership from the service org, and, if they held a `platform` permission, `authsetup --env dev revoke-platform <their email> <permission> --reason "left Acme"` (SOP 10; it also revokes their keys in that org that carry it; `platform-holders` shows what they held). Their user tokens expire within 15 minutes; a backend using server-side permission checks (SOP 06) cuts them off at once.

**6. Change the admin password.** The admin is an ordinary account: change it on the auth service (password change or reset for `invoicer-admin@acme.example`), then update `admin.password` in `invoicer.<env>.json` so the tool can still sign in. There is no rotate command for it.

**7. Tear everything down (rare).** Preview first: `authsetup --env dev --config-dir ./config --dry-run destroy` lists every org, team and member it would remove. Then `authsetup --env dev --config-dir ./config destroy` removes the users org, the consumers org and the service org, children first, after you type the service id. It is permanent on the server; the credential files are kept as your audit trail. Never on prod without a written decision. The default directory `~/.authmesh/invoicer/` also holds your **other** environments (prod included), so when you no longer need the destroyed environment's files, move aside only those (`*.dev.json`), never the folder; from 0.5.25 its NEXT prints exactly that: `mkdir -p ~/.authmesh/invoicer/.archive && mv ~/.authmesh/invoicer/*.dev.json ~/.authmesh/invoicer/.archive/`.

## What you'll see

`disconnect` warns `disconnect "billing": this REVOKES key <id>. Any service still using this key will immediately start returning 401.` and then `revoked key <id>` and `archived local cred → …/.archive/billing-consumer.dev.<timestamp>.json (not deleted)`. `connect` afterwards prints `minted scoped key <new id>`. The OAuth clients' management tokens rotate themselves when the tool updates redirect URIs; nothing to do.

## If it goes wrong

- `nothing to disconnect — no saved consumer credential for "billing" in this env`: wrong `--env` or `--as`; credentials are per environment and per identity.
- `refusing to revoke without confirmation on a non-interactive terminal — pass --yes to bypass (automation) or run interactively`: you piped it (from 0.5.24 `</dev/null` counts as not a terminal too).
- After changing the admin password (step 6) without updating the file: `the saved admin credentials (admin …, file …) no longer sign in to …` on the next run; put the new password in `admin.password` of that file. `authsetup --env dev doctor --strict` checks the sign-in on demand.
- `could not authenticate as the saved consumer … to revoke its key`: the stored password no longer works. Revoke from the provider's side or the auth API, then archive the file by hand.
- Revoked the wrong key: it cannot come back. `connect` again (consumer); for the service key just `authsetup --env dev --config-dir ./config run` (0.5.27 re-mints a revoked one), then re-wire.
- `status` / `doctor` say `service API key <id> no longer works (revoked or deleted)`: run the command its NEXT prints (`authsetup --env dev --config-dir ./config run`), then `settings --env-file .env`, and restart your app so it loads the new key (`status` cannot see your app; its "nothing to change" is about the mesh only). Do **not** point `--creds-dir` at a new folder: that starts a second setup and stops on `is taken`.
- `doctor` says `service key ◐ UNDER-PERMISSIONED`: you added permissions to config after minting. Rotate per step 1.

## Coming

- **`authsetup rotate-key`** (service key): mint, print the wiring with the value masked, and revoke the old key after you confirm the new one is deployed. *Today:* step 1.
- **`authsetup revoke-key <id>`** from the CLI. *Today:* the API call.
- **Full self-delete of a consumer account on `disconnect`.** *Today:* the key is revoked and the account stays, inert.
- **Admin password rotation from the CLI.** *Today:* step 6.

## Next

SOP 15, migrations and upgrades.
