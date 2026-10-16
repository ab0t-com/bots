# Scenario selection · success rubric · step decomposition

The three design decisions a blank `uj new` leaves entirely to you.

## 1. Which journey is worth writing?

Don't start from an endpoint ("I'll test POST /orgs"). Start from the business stake. Strong
candidates, in rough priority:

| Category | Ask | Example |
|---|---|---|
| **Activation / first value** | What must work for a new user to reach their first "aha"? | signup → create workspace → see first result |
| **Trust-critical action** | What, if broken, breaks user trust or safety? | revoke access → access actually gone |
| **Churn / money moment** | What touches billing, quota, or a paid feature boundary? | upgrade plan → premium feature unlocks |
| **Cross-actor collaboration** | Where do two personas interact and a boundary must hold? | owner invites → teammate accepts; outsider refused |
| **Lifecycle end** | What must be cleaned up when something ends? | offboard partner → credentials die immediately |

Pick ONE stake per journey. If you can't name the stake in a sentence, you're testing an endpoint,
not a journey — reconsider.

## 2. Writing `success:` — a business fact, not a status code

`success:` is the whole point of the journey stated as a promise. Lint (JL008) only checks it's
non-empty; the rigor is on you.

| Weak (avoid) | Strong (aim for) |
|---|---|
| "the endpoints return 200" | "a revoked contractor loses access everywhere within one check — no grace window" |
| "step 3 works" | "a free-tier org cannot use the premium export until it upgrades, and an outsider never can" |
| "the invite API responds" | "an invited teammate can log in and see the shared org; a non-member cannot" |

Test: read your `success:` to a non-engineer. If they can tell whether the product kept its promise,
it's strong. If they'd ask "so what?", it's a status code in disguise.

## 3. Decomposing a flow into steps

A step = **one meaningful state change from the user's point of view**, not one HTTP call.

- "Log in" is usually ONE step even if it's two requests under the hood.
- Combine setup requests that don't carry an assertion the journey cares about (or push them into the
  Environment `setup:`, which every journey reuses).
- Split when the value moment deserves its own assertion — e.g. keep "revoke" and "verify revoked" as
  two steps so the *verify* is where you assert `valid: false`.
- **Use as many steps as it takes to SIMULATE a real session.** There is NO upper cap — a believable
  user session is the goal, and real sessions are long (orient, do several normal things, then the
  moment under test, then wind down). A 10–20 step session that reads like a real person's afternoon is
  BETTER than an artificially short one. Keep it readable by pulling the recurring normal-activity blocks
  into `use:` fragments — length lives in the fragments, the session stays legible. (A late-failing step
  is cheap to retry: `--resume` re-runs from the failure with state intact, so long journeys cost you nothing.)
- The only lower bound: fewer than ~3 steps is usually a single call dressed up as a journey — that's a
  functional check, not a session. If it's that short, it probably isn't a realistic session yet.
- The steps must trace ONE coherent persona's path. If step 2 is the owner and step 3 is an outsider,
  that's fine ONLY if the outsider step is an `abuse:` check — otherwise the journey has lost its
  narrative and is just a pile of calls.

## The value moment

Every journey has one step that is the reason it exists — the moment the promise in `success:` is
proven (the revoked key gets rejected; the premium export finally works). Make THAT step assert the
most (`schema`/`body`), and make sure a prior step set up the state it needs (a capture it consumes).
Everything else is scaffolding around that moment.
