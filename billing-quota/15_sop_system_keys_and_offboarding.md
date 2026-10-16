# 15 · Keys and offboarding

**What this is for.** The two keys your service holds for billing and payment: rotating them on schedule, revoking one that leaked, and leaving a provider. Plus the other direction: a customer leaving you, and a user asking to be forgotten.

**Before you start.** Ally's SOP 14 (it owns the `authsetup` mechanics; this SOP only adds the money-specific order of operations). `authsetup --env <env> status` shows both connections.

## Steps

**1. Rotate a billing or payment key (no downtime).**
```sh
authsetup --env prod disconnect billing --as invoicer --dry-run      # what would be revoked and archived
authsetup --env prod disconnect billing --as invoicer                # type "billing"; the OLD key is revoked NOW
authsetup --env prod connect    billing --as invoicer                # new key, same tier
```
Because `disconnect` revokes immediately, order matters for a live service: **first** ask the provider to mint a second key for your consumer account (or `connect` with `--email` to a fresh address if you accept a new account), deploy the new value as `AB0T_QUOTA_BILLING_TOKEN`, confirm `quotactl capabilities` shows `Billing: true` and a usage record lands, **then** revoke the old key. If you cannot get a second key, rotate in a maintenance window and expect `401`s from billing between revoke and deploy. Repeat for payment. The quota library reads tokens at start; a token change is a restart.

**2. A key leaked.** Revoke first: `authsetup --env prod disconnect <provider> --as invoicer` (or `DELETE /api-keys/<id>` as the consumer account). Then step 1 to re-establish, then read your journals (`~/.authmesh/invoicer/journal/`) and billing's transaction history for the exposure window. A leaked **billing** key with write permissions can record usage against your customers: check `GET /billing/<org>/transactions` for the period.

**3. Leave a provider for good.** `disconnect` revokes the key and archives the local credential; the consumer account remains on the provider's side, inert. Remove `AB0T_QUOTA_*` for that provider from your env; the library then starts with that capability off and says why.

**4. A customer leaves you.** In this order: cancel their subscription (`DELETE /subscriptions/<org>/<id>`, default at period end; the portal does the same), let the final invoice settle, release every gauge they hold (`q.Release`), optionally refund unused prepaid balance through payment's refund routes (their policy applies; `authority` is required above a threshold), then remove their membership in your users org (Ally SOP 09). Their billing account stays as the ledger of record; you do not delete it.

**5. A user asks to be forgotten.** The quota library holds per-user data only in the handler ledger (grant rows). `quotactl delete-user --user-id <id>` is the intended verb, but today the standalone CLI operates on an in-memory stub, so it deletes nothing from your real ledger (see *Coming*); delete the rows through your service's own admin path, then handle auth (Ally) and billing/payment (platform team) separately. Counters are per org and carry no user identity beyond optional per-user sub-counters, which expire.

**6. Your own secrets hygiene.** `AB0T_AUTH_WEBHOOK_SECRET` (auth events) is rotated by replacing the subscription, because re-running `quotactl subscribe-events` keeps the existing subscription and its old secret: SOP 10 step 7. You hold no Stripe webhook secret even if you forward Stripe's webhooks (payment verifies the signature). Alert webhook URLs may carry a token; rotate with the endpoint.

## What you'll see

`disconnect`: `revoked key <id>`, `archived local cred → ~/.authmesh/invoicer/.archive/billing-consumer.prod.<timestamp>.json (not deleted)`, and `the consumer account … still EXISTS on the server`. `connect` afterwards: `minted scoped key <new id>`. Your service after a token swap: `billing: true` in the capability line.

## If it goes wrong

- `401` from billing after rotation: the service still runs with the revoked token; restart with the new env.
- `nothing to disconnect — no saved consumer credential for "billing" in this env`: wrong `--env` or `--as`.
- The provider says they cannot mint a second key for the same account: rotate in a window, or `connect --email <fresh address>` for a second account, move traffic, then disconnect the first.
- A customer's subscription cancelled but their tier stayed: payment sets `free` on `customer.subscription.deleted`; if the webhook never arrived, SOP 08's chain walk.

## Coming

- **Overlapping key rotation in one verb** (`authsetup rotate <provider>`: mint new, wait for your confirmation, revoke old). *Today:* step 1's ordering by hand.
- **`quotactl delete-user` against the real ledger.** *Today:* in-memory stub.
- **Consumer account self-delete on disconnect.** *Today:* inert account remains.
- **A customer-offboarding checklist endpoint** (cancel + release + refund + remove) in one call. *Today:* step 4 by hand.

## Next

SOP 16, migrations and upgrades.
