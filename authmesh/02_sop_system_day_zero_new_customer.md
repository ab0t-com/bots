# 02 · Day zero: a new customer joins the mesh

**What this is for.** The whole first day, in order, for one example customer, so you know what is coming before you type anything. SOPs 03–06 are the same moves with every detail.

**Before you start.** Nothing. Ten minutes to read.

## Steps

Say **Acme** wants to put their service **`invoicer`** on our mesh.

**1. Install the tool (once).**
One command installs `authsetup`; `authsetup version` should say `0.5.24` or later. It's the only thing Acme needs to talk to us (SOP 03).

**2. Describe the service: `authsetup init --publish`.**
A short wizard asks for the service's name, its web address, what things it manages and how its users are organised, then writes a `config/` folder (checked by the same validator as step 3; nothing is sent anywhere). The important file is `permissions.json`, a plain list of what people can do in `invoicer`:
- `invoicer.read.invoices`: everyone gets this (`default_grant: true`).
- `invoicer.write.invoices`: given out by the customer's admins.
- `invoicer.admin`: admin of invoicer **inside your own org**.
- `invoicer.support.read_all`: Acme's support staff can see **every** customer's invoices, so Acme adds it and marks it `"scope": "platform"`.

That last line is the only new thing to learn. Anything that reaches across customers gets `scope: platform`; everything else is left alone (SOP 01).

**3. Check it: `authsetup validate`.**
It checks the file without touching any server. If Acme forgot to mark `read_all` as platform, or made it a default for every user, it says so and names the line to fix.

**4. Set it up: `authsetup --env dev up`.**
It shows the plan in plain words (your app, your users, your partners) with the environment in the banner, waits for Acme's yes, then in one go:
- checks the name `invoicer` is free in the permission registry **before creating anything** (if another organization owns it, it stops and says so; nothing is left behind);
- creates Acme's **service org `invoicer`**, which owns the `invoicer.*` permissions from now on;
- registers the permission list;
- creates Acme's admin account and **service key**, the admin granting itself the declared platform permission first (no platform admin involved);
- sets up the sign-in client and Acme's **branded login page**;
- creates the **`invoicer-users` org**, where Acme's customers will land, with a default team holding the default permissions;
- checks everything, signs up a throwaway test user end to end, and removes that user again.

Credentials are saved privately in `~/.authmesh/invoicer/`. `authsetup --env dev settings --env-file .env` puts the key and the other values into the app's `.env` (the key is never shown on screen), `authsetup --env dev snippet login` prints the sign-in block for the web page, and invoicer is live on dev. Production is the same files with `--env prod` (SOP 05).

**5. Acme's customers start signing up.**
They use Acme's login page and land in `invoicer-users`, automatically getting the default permissions. If Acme chose "workspace per user", each customer also gets their own private org, where they're the admin. There they can invite teammates and hand out `invoicer.write.invoices` or `invoicer.admin` **for their own org only**. They can never get `invoicer.support.read_all`.

**6. Acme's own staff.**
Only Acme's admins can give a teammate a **platform** permission like `invoicer.support.read_all`: one person at a time, with a reason, and logged: `authsetup --env dev grant-platform dana@acme.example invoicer.support.read_all --reason "Tier-2 support rota"` (SOP 10).

**7. Using other mesh services.**
If invoicer needs billing: `authsetup --env dev providers` lists what's available, and `authsetup --env dev connect billing --as invoicer` gets invoicer its own scoped billing key (SOP 11).

**8. Letting others use invoicer.**
Step 08 of the same `up` opens invoicer to other services, with default access tiers. A partner joins the default (read-only) tier on its own; anything more needs Acme's approval (SOP 12). No platform staff involved.

**9. Changing anything later.**
Edit `config/`, then `authsetup --env dev up` again. It shows only what's different and asks before changing it. There's no separate update command (SOP 13).

## What you'll see

**In short, for Acme:** one config file, one new word (`scope: platform`) for the few cross-customer powers, and the CLI does the rest. Acme's customers manage their own orgs; only Acme hands out Acme's platform powers; our platform admin is only an override, never a step in onboarding.

## If it goes wrong

Every message the tool prints says what happened and what to do; SOP 16 lists them all. The two a first day most often meets: the service name is taken (choose another `registration.service`, SOP 05) and a command that went to production because no `--env` was given (SOP 03).

## Coming

Nothing on this path; the individual SOPs list their own Coming items.

## Next

SOP 03, install and pick your environment.
