# 12 · Opening your service to other services

**What this is for.** Letting other mesh services call *your* API with their own scoped keys, without you provisioning anything per partner. You publish **tiers**; they `authsetup connect invoicer`; auth enforces that each key holds only what its tier grants.

**Before you start.** SOP 05 done (steps 01–04 at least). You know which of your permissions are safe to hand to a stranger's backend (read-only, inside their own customers' data) and which are not.

## Steps

**1. Decide your tiers, and whether strangers may sign themselves up.** If you do nothing, `run 08` derives two safe tiers from `permissions.json` and prints them: `Read-Only Consumers` (default; every non-privileged `*.read*` permission) and `Standard Consumers` ("Your default permissions (the default_grant set)"). Also by default, **self-serve sign-up is off**: you are listed in the directory but closed, and partners need an invitation from you. To open it, or to customise tiers, create `config/api-consumers.json`:
```json
{
  "consumer_org": { "name_suffix": "API Consumers", "slug_suffix": "api-consumers" },
  "tiers": [
    { "name": "Read-Only Consumers", "default": true,
      "description": "Dashboards and reporting",
      "permissions": ["invoicer.read.invoices"] },
    { "name": "Integrations", "default": false,
      "description": "Create and edit invoices inside the consumer's own customers",
      "permissions": ["invoicer.read.invoices", "invoicer.write.invoices"] },
    { "name": "Support partners (invite)", "default": false, "privileged_ack": true,
      "description": "Reads every customer — invite only",
      "permissions": ["invoicer.read.invoices", "invoicer.support.read_all"] }
  ],
  "registration": { "signup_enabled": true, "default_role": "service_account" },
  "public_mesh": true,
  "docs_url": "https://invoicer.acme.example/docs",
  "quickstart_url": "https://invoicer.acme.example/docs/quickstart",
  "support_url": "https://acme.example/support",
  "connect_prompt": "Connect to Invoicer to read and create invoices for your customers."
}
```
Rules the tool enforces:
- Exactly one tier is `default: true`; that is what a stranger gets instantly, with no approval. Keep it read-only.
- A tier that carries a cross-customer (`platform`) permission must be **non-default** and marked **`privileged_ack: true`**. Consumers reach it only when you move them in (step 4).
- `public_mesh: false` keeps you connectable by id but out of the public directory. `docs_url` is expected for public providers; the other URLs are optional and are shown on your directory card.

**2. Validate, preview, apply.**
```sh
authsetup --config-dir ./config validate
authsetup --env dev --config-dir ./config --dry-run run 08
authsetup --env dev --config-dir ./config run 08
```
Step 08 first checks your permission schema as your service org (publishing tiers for a schema you do not own would advertise permissions you cannot grant, so a schema problem stops step 08 here; SOP 16). Then it creates the **`invoicer-api-consumers`** org under your service org, one team per tier (permissions reconciled **exactly**: it adds what config has and removes what it does not), the sign-up settings (consumers auto-join the default tier when sign-up is on), and publishes you to the directory. `up` runs step 08 too.

**3. Tell partners how to connect.**
```sh
authsetup --env dev providers                                   # they see your card
authsetup --env dev connect invoicer --as <their-service>        # only when sign-up is on; otherwise invite them
```
They never need your credentials. Their key arrives scoped to the default tier; your API validates it as an API key (SOP 06) and gets `org_id` + `permissions` back. Partner keys carry no audience, so check your audience on user tokens only (`WithExpectedJWTAudience` in Go, SOP 06).

**4. Move a partner to a higher tier.** Today this is a manual act by your admin: add the consumer's service account (its email is in the registration your partner shows you, or in your org's member list) to the tier's team as a `member`, using the teams API on the `invoicer-api-consumers` org. Then the partner re-runs `authsetup --env dev connect invoicer --as <them> --tier "Integrations"` to mint a key for that tier. For a tier carrying a `platform` permission, also grant it to the partner's service account in its sub-org: `authsetup --env dev grant-platform <their account email> <permission> --org <their sub-org id> --reason "…"` (SOP 10). See *Coming*.

**5. Tighten a tier later.** Edit the tier's `permissions`, `run 08`. Existing keys keep what they were minted with; ask affected partners to reconnect (`disconnect` + `connect`, SOP 14) to pick up the new set.

## What you'll see

With sign-up **off** (the default), `run 08` says `self-serve sign-up for consumers is OFF: they need an invitation from you (to let them self-register, set registration.signup_enabled: true in ./config/api-consumers.json)` and ``published invoicer to the mesh directory — listed but closed: consumers see it in `authsetup providers` and need an invitation``; partners see you as `closed — invitation only`. With sign-up **on**: `consumers self-register with: POST https://auth.dev.ab0t.com/organizations/invoicer-api-consumers/auth/register then POST /api-keys/` and ``published invoicer to the mesh directory — discoverable via `authsetup providers`/`connect` ``. With `public_mesh: false`: `registered invoicer in the mesh directory as UNLISTED (public_mesh:false)`. The register URL and tier ids are saved in `api-consumers.<env>.json`. Re-runs print `~ re-sent: PUT login-config on consumers org (…)`; that is not a change.

## If it goes wrong

- `api-consumers: tier "Read-Only Consumers" is default:true (auto-join) and grants privileged perm "invoicer.support.read_all" — move it to a non-default privileged_ack tier`: exactly what it says.
- `api-consumers: tier "Support partners (invite)" grants privileged perm "…" without privileged_ack:true`: add the ack, keep it non-default.
- `no tier is marked default:true — consumers would auto-join nothing`: mark one.
- `could not publish invoicer to the mesh directory (non-fatal)`: the register URL still works; partners can `connect invoicer` by id. Re-run later.
- A partner's key `403`s on a call you expected to allow: their tier does not include that permission, or they minted before you widened it. Reconnect.

## Coming

- **`authsetup approve <consumer> --tier "Integrations"`** (and `--revoke`): your admin moves a partner between tiers from the CLI; the approval lands in the partner's own sub-org automatically. *Today:* step 4 by API, plus `grant-platform --org` for a platform permission.
- **`authsetup consumers`** to list who is connected, at which tier, with which key ids. *Today:* the org's member and team lists on the API.
- **Tier names free of legacy wording.** Some providers' tiers still carry older names for the cross-customer capability; the approved term is `scope: "platform"`.

## Next

SOP 13, changing things safely.
