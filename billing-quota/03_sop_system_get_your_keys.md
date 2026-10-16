# 03 · Get your billing and payment keys

**What this is for.** Your service needs its own scoped keys to call billing (record usage, read balances, reserve funds) and payment (checkout, portal, subscriptions) **on behalf of your customers**. This SOP gets you connected, tells you honestly what the self-serve tier does and does not allow today, and hands the `authsetup` details to Ally's SOPs.

**Before you start.** `authsetup` installed (Ally SOP 03). Your service name for `--as` (`invoicer`). Decide the environment: `dev` first. `authsetup` defaults to **prod**; write `--env` on every command.

## Steps

**1. See the two providers.**
```sh
authsetup --env dev providers
```
Both billing and payment publish three tiers. Read them carefully:

| tier | default | what it grants |
|---|---|---|
| Read-Only Consumers | yes (zero-touch) | billing: `billing.read`, `.read.accounts`, `.read.reservations`, `.read.transactions`, `.read.usage`, `.read.reports`, `.read.financial_reports`. payment: `payment.read` and every `payment.read.*` |
| Standard Consumers | no | reads only, despite the description saying "read + write" |
| Cross-Tenant (invite) | no, `privileged_ack` | only the cross-customer capability itself |

**No published tier grants a write.** Recording usage needs `billing.write.usage`; reserving needs `billing.write.reservations`; committing needs `billing.write.transactions`; a checkout needs `payment.write`. And acting on a *customer's* org needs the cross-customer capability on top. See *Coming*.

**2. Connect to both, same identity, preview first.**
```sh
authsetup --env dev connect billing --as invoicer --dry-run
authsetup --env dev connect billing --as invoicer
authsetup --env dev connect payment --as invoicer
```
Use the same `--as` for both so they sit under one identity. Each prints the two env vars it expects you to set and the file holding the key (`~/.authmesh/invoicer/billing-consumer.dev.json`, `payment-consumer.dev.json`, field `.api_key.key`). The key value is never printed.

**3. Wire the keys the way the quota library reads them.**
`connect` prints `BILLING_SERVICE_URL` / `BILLING_SERVICE_API_KEY`. The Go library reads **different names**:
```
AB0T_QUOTA_BILLING_URL=https://billing.service.ab0t.com         # use the BILLING_SERVICE_URL that `connect` printed for your environment
AB0T_QUOTA_BILLING_TOKEN=<read .api_key.key from ~/.authmesh/invoicer/billing-consumer.dev.json>
AB0T_QUOTA_PAYMENT_URL=https://payment.service.ab0t.com
AB0T_QUOTA_PAYMENT_TOKEN=<read .api_key.key from ~/.authmesh/invoicer/payment-consumer.dev.json>
```
`AB0T_QUOTA_SERVICE_TOKEN` is a shared fallback used when a provider-specific token is unset; billing's key is not valid at payment and vice versa, so prefer the two specific names. A token beginning `ab0t_sk_` is sent as `X-API-Key`; anything else as a bearer. The Python library reads `AB0T_MESH_API_KEY` and `AB0T_CONSUMER_ORG_ID` instead (SOP 05).

**4. Prove each key.**
```sh
authsetup --env dev status --verify
```
Both rows turn `● LIVE` when the provider accepts the key. (`/health` on billing and payment is public: a `200` there says the service is up, not that your key works.) A real read, as your own org: `GET /billing/<your org id>/balance` with `X-API-Key` returns `balance`, `credit_balance`, `subscription_credit`, `reserved_balance`, `available_balance`; the same call without the header is a `401`.

**5. Ask for the gateway tier.** Tell the provider (platform team, `platform-team@ab0t.com`) your consumer account email (printed by `connect`) and what you do: *"invoicer records usage and starts checkouts for its customers' orgs"*. Name the writes you need: `billing.write.usage` (metering), `billing.write.reservations` + `billing.write.transactions` (reserve/commit), `billing.write.refunds` (release), `payment.write` (checkout, subscriptions, setup intents). Do not ask for `billing.admin` or `payment.admin` unless you administer plans yourself. Once they upgrade your account, re-run `connect` (it adopts the account and re-mints if the tier changed), or they hand you the key.

## What you'll see

`connect`: `registered consumer account invoicer-billing-…@mesh-consumers.ab0t.com in billing-api-consumers`, `minted scoped key <id> for tier "Read-Only Consumers" (7 perms)`, then the env wiring. `status` shows two rows, `◐ WIRED` until `--verify` promotes them to `● LIVE`.

## If it goes wrong

- `provider "billing" did not grant every permission tier "Standard Consumers" requests`: you asked for a non-default tier; connect on the default, then step 5.
- `403 {"error":"PERMISSION_DENIED","message":"One of permissions required: billing.write.usage, …"}` on your first usage record: expected on the read-only tier. Step 5.
- `403 … "Access denied - different organization"` (billing) or `"Access denied to organization data"` (payment) when the path org is a customer's: your key lacks the cross-customer capability. Step 5.
- `401` from billing with a key that works at payment: wrong token for the wrong provider. Keys are per provider.
- Anything `authsetup` itself says: Ally SOP 16.

## Coming

- **A metering tier you can join without asking** (writes scoped to your customers' orgs), approved into your sub-org by the provider's own admin under the scope model, instead of today's read-only default plus a manual upgrade. *Today:* step 5.
- **The "Standard Consumers" tier actually carrying writes**, or being renamed. *Today:* it is reads only.
- **Tier names free of legacy cross-customer wording.** *Today:* "Cross-Tenant (invite)".
- **`connect` printing the quota library's env names** (`AB0T_QUOTA_*`). *Today:* translate per step 3.

## Next

SOP 04, describe your tiers and resources.
