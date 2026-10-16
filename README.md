# Build on the ab0t mesh, with a colleague who has done it before

You have a product. You want people to sign in, you want to know what they use, and you want to
charge them for it. You do not want to become an expert in identity, ledgers or Stripe to get there.

That is what the mesh is for, and these bots are how you use it.

## What it looks like

**Monday morning.** Acme's `invoicer` is a Go service with no login. Ally installs one tool, asks
four questions about the service, writes a small config, shows Acme the plan and asks "shall I?".
Ten minutes later there is a branded sign-in page, a key for the backend, and a test user who can
read invoices but not write them. Acme pastes two values into their app and ships.

**Tuesday.** Acme wants a free tier with twenty invoices a month and a $29 Pro tier. Penny asks what
costs Acme money (rendering PDFs, not "requests"), writes one JSON file, adds a few lines to the API,
and runs it in shadow mode for a day. Nobody is blocked; Acme sees that four free customers would
have hit the limit. Penny creates the Pro plan in dollars, wires an "Upgrade" button that opens
Stripe, and turns enforcement on. Two customers upgrade that afternoon.

**A month later.** A customer says they paid but still see the free tier. Penny walks the chain in
order, finds the step that did not happen, and says exactly who fixes it and how.

## What makes it comfortable

- **Plain words first.** The bots talk about customers, plans and invoices, not tokens and tuples.
- **Nothing changes without your yes.** Every bot previews, then asks.
- **Your secrets stay yours.** Keys land in a private folder on your machine; the bots point at
  them, never print them.
- **Honest about what is not there.** When a step is not built yet, the SOP says **Coming** and
  gives you today's way. The list of those is public.
- **Readable without the bot.** Every procedure is a short page a person can follow alone.

## Start

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/authmesh/install.sh | sh        # Ally
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/billing-quota/install.sh | sh   # Penny
```
Or several at once: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/install.sh | sh -s -- authmesh billing-quota`
(`sh -s -- all` for every bot; [`index.md`](index.md) lists them). Then open Claude Code and say what
you want: "put my service on the mesh", "add a free and pro tier". Or just read: [`index.md`](index.md).

The installers only download this repository's folders and link them into `~/.claude`; they talk
to no ab0t service and read no credentials. Skill folders you already have are never deleted.

## Licence

MIT ([`LICENSE`](LICENSE)). A few files are adapted from third-party works and keep their own
licences (a skill's `license:` field says so); see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

*ab0t · questions and support: platform-team@ab0t.com*
