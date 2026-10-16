# 01 · The scope model, in plain words

**What this is for.** One idea you need before you write your permissions: some permissions act inside one customer's org, and a few reach across all your customers. You say which is which with one word, and the mesh enforces the rest. In `authsetup` since 0.5.21; what is still not built is under *Coming*.

**Before you start.** Nothing. Five minutes.

## The idea

**One extra word in your config.** Each permission in your service's `permissions.json` can carry `"scope"`:
- **`org`**, the default: it only ever acts inside one customer's org. Most permissions are this, including `invoicer.admin` ("admin of invoicer inside your own org").
- **`platform`**: it reaches across customers, such as an operator kill switch or a support view of every customer. You mark these few yourself; that is the whole decision.

**Using it switches your service to "declared" mode.** As soon as one permission in your file carries `scope`, the whole service is judged by what you declared, and every permission you did not mark `platform` is `org`. A file with no `scope` at all keeps the older rule: the auth service guesses "cross-customer" from the *name* (words such as `cross`, `global`, `read_all`, `superadmin`, and `<service>.admin`). Declaring is what makes `invoicer.admin` an ordinary permission.

**`authsetup validate` keeps you honest** (declared mode).
- A permission whose name sounds like it reaches across customers (`cross`, `global`, `platform`, `tenant_gateway`, `_wide`, `read_all`, `superadmin`) but is not marked `platform` stops validation and names the line.
- A `platform` permission, or one with `risk_level` `high` or `critical`, may not be `default_grant`, in the default role, or in `default_team_permissions`.

**`authsetup up` (or `run`) does the registering.**
- Step 01 registers your permission list with the declaration, and your service org becomes its owner.
- Your service's own admin account then grants itself the `platform` permissions you declared and mints your service key with them. No platform admin, no ticket.

**Your own team.** Only admins of your service org can hand out your `platform` permissions: one person, one permission, with a written reason, every grant logged. `authsetup grant-platform`, `revoke-platform` and `platform-holders` do it from the CLI (SOP 10). It never happens through roles or teams, so nobody gets one by accident.

**Your customers** (the orgs using your service). Their admins can give their own people your `org` permissions, including `invoicer.admin` for their own org. They can **never** give anyone your `platform` permissions, not even themselves.

**Other services calling yours.** A partner that needs a `platform` permission sits in a non-default tier you approve (SOP 12). In the in-house variant (`run 07`, SOP 11) your admin's approval lands in the partner's own sub-org automatically.

**End users** see no change.

**In one sentence:** the service that defines a permission decides who gets it; auth enforces that; auth's platform admin can always override.

## What you'll see

`validate` naming a line: `permission "invoicer.support.read_all" reaches across customers by its name (…) — set "scope": "platform" on it, or rename it if it really acts inside one org`. Once your service org exists, step 01's schema line names it and the declaration: `register permission schema for "invoicer" as service org <id> — admin surface (declares N platform permission(s): […])` (the list also includes generated ids whose names carry a reach word, such as `invoicer.read.read_all`).

## If it goes wrong

- Your auth service is older and refuses the owner's grant: step 01 says `owner sanction … refused by auth … — continuing; the mint below decides`, and the key mint may then ask for the platform admin (SOP 05). Tell the platform team which environment.
- `grant-platform` says your service `has not declared scope yet`: add `"scope": "platform"` to the cross-customer permissions, `validate`, then `up`.

## Coming

- **Partner tier moves approved from the CLI** (`authsetup approve`), landing in the partner's sub-org automatically. *Today:* SOP 12 step 4 by API.
- **Automatic revocation of everything the previous owner handed out** if your service ever changes owner (rare; done by the platform admin). *Today:* manual.

## Next

SOP 02, a new customer's first day, end to end.
