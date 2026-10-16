# 11 · Using other services (billing, payment, and the rest)

**What this is for.** Your service needs to *call* another mesh service: record usage with billing, start a checkout with payment, write audit events. You become that service's **consumer**, get your own scoped key, and send it as `X-API-Key`. No provider credentials, no ticket.

**Before you start.** SOP 03 done (that is all; you do not need a published service of your own to consume one). Your service name for `--as` (`invoicer`). Pick the environment.

## Steps

**1. See who you can connect to.**
```sh
authsetup --env dev providers
```
One card per provider: its id, where to register, each **tier** with the exact permissions it grants, and the `connect` line to copy. The header counts them: `N mesh provider(s) listed — X accept self-serve consumers, Y closed (invitation only)`. The tier marked `[default — zero-touch]` is the one anyone may join instantly. Higher tiers may not publish their permissions and need the provider's approval after you connect. A provider marked `closed — invitation only` gets no `connect` line: ask it for an invitation. `--json` prints exactly one JSON document (from 0.5.24; drop any old line-stripping workaround).

**2. Connect. Preview first.**
```sh
authsetup --env dev connect billing --as invoicer --dry-run
authsetup --env dev connect billing --as invoicer
```
In one go it creates a consumer account for `invoicer` in `billing-api-consumers`, mints a key holding exactly the tier's permissions, and saves it 0600 to `~/.authmesh/invoicer/billing-consumer.dev.json`. The key value is **never printed**. Re-running reuses the key (`already connected to billing (tier "Read-Only Consumers") — key … reused`). `--tier "<name>"` asks for a specific tier; `--email` pins the account address.

**3. Wire the two values it prints.** On production:
```
BILLING_SERVICE_URL=https://billing.service.ab0t.com
BILLING_SERVICE_API_KEY=<read .api_key.key from ~/.authmesh/invoicer/billing-consumer.prod.json>
# Go services using ab0t-quota-go read instead:
AB0T_QUOTA_BILLING_URL=https://billing.service.ab0t.com
```
Off production (`dev`, `local`) the URL is left empty on purpose, with the line `# BILLING_SERVICE_URL: not published for this environment — ask the provider for its URL`. Before 0.5.24 it printed the production address there, which would have sent a dev key to production; ask the provider for its dev address instead of guessing.

Load the key from your secrets manager; send it as `X-API-Key` on every call to the provider. Never forward a user's bearer token to another service (wrong audience, wrong permissions), and always take the customer's `org_id` from the validated token, never from the request.

**4. Verify.**
```sh
authsetup --env dev status --verify        # pings each key; WIRED → LIVE
```
Then call the provider's health route from your service with the key it now holds (`X-API-Key`) against that environment's `BILLING_SERVICE_URL`.

**5. Billing and payment specifically.** Connect to both with the same `--as invoicer` so they share one identity. The default tier is read-only; a product that *records usage* or *creates checkouts on behalf of its customers* acts across its customers' orgs and therefore needs the provider's cross-customer tier, which is a `platform`-scope capability. Ask the provider to upgrade your consumer account after you connect (step 2 output names the account). When you have the keys, metering, plans, checkout and webhooks are the billing-quota bot's job (Penny, `github.com/ab0t-com/bots`, folder `billing-quota/`; its SOPs 03, 05, 07, 08 and 11).

**6. The in-house variant: `clients.d/` + `run 07`.** If you operate *inside* the same organisation as the provider and hold its admin credentials file, declare the relationship in `config/clients.d/<provider>.json` (`provider.service_id`, `provider.credentials_path`, `client.service_id`, `permissions[]`, `api_key.name`) and `authsetup --env dev --config-dir ./config run 07`. It creates a customer sub-org under the provider and mints a key the same way, reconciling every file in that folder on each run. When the provider declares `scope` and you need its `platform` tier (`privileged_tier`, `privileged_ack: true`, `privileged_perms` in that file), the provider's own admin sanctions it into your sub-org during the run; no platform admin. External customers do not use this path; `connect` is yours.

## What you'll see

`status` shows one row per connection in a small state machine: `· NOT_STARTED  ○ REGISTERED  ◐ WIRED  ● LIVE  ⨯ FAILED`, with provider, environment, tier, masked key id and last verification. `○ REGISTERED` with no key is an orphan from an interrupted mint; re-run `connect` to adopt it rather than making a new account.

## If it goes wrong

- `this auth service has no mesh provider directory yet (GET /mesh/providers → 404)`: the directory is not deployed on that environment; try another `--env`.
- `no mesh provider "biling"`: typo, or wrong environment. `authsetup --env dev providers` lists valid ids.
- `tier "Pro" not offered — available: Read-Only Consumers, Standard Consumers`: pick a listed name or drop `--tier`.
- `tier "Integrations" does not publish its permission set in the directory — connect to the provider's default tier, or ask the provider to upgrade you after connecting`: exactly that.
- `provider "billing" did not grant every permission tier "Standard Consumers" requests — the default tier is zero-touch; higher tiers require the provider to upgrade your account`: connect on the default tier, then ask the provider.
- `consumer account … already exists but the stored password did not authenticate`: the account was created from another machine. Use that machine's `~/.authmesh/invoicer/`, or `--email` a fresh address.
- `provider "x" has self-serve registration disabled` / `has no consumer org published — it has not completed run 08`: ask the provider for an invitation.
- `429`: the auth service allows about five requests a minute; wait a minute and re-run, it adopts what it created.
- `run 07`: `co-located mode needs the provider's creds file`: you do not have the provider's credentials. Use `connect`.

## Coming

- **Tier upgrades for `connect` customers approved by the provider's own admin from the CLI.** *Today:* ask the provider (SOP 12 step 4). For in-house `run 07` against a provider that has not declared `scope`, the key mint may still need the platform admin's sanction (`AUTHSETUP_PLATFORM_ADMIN_TOKEN`).
- **`authsetup connect` printing a ready `.env` fragment** per language. *Today:* the two lines in step 3.
- **Self-delete of the consumer account on disconnect.** *Today:* the key is revoked and the account stays, inert (SOP 14).

## Next

SOP 12 to let other services use yours; SOP 14 to rotate or revoke a connection.
