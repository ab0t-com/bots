# 10 · Test end to end: across services and through the UI

**What this is for.** A customer's story often crosses more than one system. At Acme, Sam presses Send in the `invoicer` web app, `invoicer` marks the invoice sent, and Acme's mailer service queues an email to the client. This SOP shows the real ways to test that whole path today. Read the first step carefully: it is the one limit you must design around.

**Before you start.** SOPs 07–09. The dev addresses of the other services involved (Acme's mailer here; yours will differ). `bash` and `curl` on the machine that runs uj: `run:` steps are started with `bash -c`. For UI steps, a browser driver you provide (step 6).

## Steps

**1. Pick the one target.** A journey has **one target** per run: every `path:` is joined to it, and `{base}` is its URL. Pick the service where the person acts (`invoicer`). Everything else is reached from a `run:` step or a `browser:` step. First-class multi-service journeys are Coming.

**2. Put the other services' addresses in environment variables.** Never in the file:
```sh
export ACME_MAILER_URL=http://localhost:8090      # Acme's mailer on dev
export ACME_WEB_URL=http://localhost:3000         # Acme's web app on dev
```
On your machine they can sit in the project's git-ignored `.env` instead, one `ACME_MAILER_URL=http://localhost:8090` line each, with no comment after the value (SOP 05). In CI they come from the job's variables or secret store (SOP 12).

**3. Check the other service with a `run:` step.** A `run:` step runs a shell command instead of an HTTP call. It passes when the command exits `0` (or the `expect: { exit: N }` you set). `{vars}` and `{env:NAME}` are filled in before the shell starts. Write other services' addresses as `{env:ACME_MAILER_URL}`, not `$ACME_MAILER_URL`: if the variable is unset, uj stops the journey as **VOID** and names it, instead of running a broken command. A `{name}` uj does not know (a `jq` filter, a Python f-string) is passed to the shell unchanged. To `capture:`, the command must print JSON on stdout. The command text is masked like every other output, so a `{token}` inside it never lands in a log or checkpoint.
```yaml
id: SENT_INVOICE_REACHES_THE_CLIENT
kind: epic
outcome: "when a freelancer sends an invoice, the client actually receives it"
persona: "Sam, sending one invoice and trusting it arrives"
success: "invoicer says sent and the mailer has a message for this invoice"
covers: [send-integrity, invoice-email]
conflicts: tenant
steps:
  - use: create_draft_invoice
  - intent: Sam sends it
    method: POST
    path: /invoices/{invoice_id}/send
    bearer: "{token}"
    expect: { status: 200, body: { status: sent } }
  - intent: within ten seconds the mailer has queued an email for this invoice
    run: |
      for i in 1 2 3 4 5 6 7 8 9 10; do
        out=$(curl -fsS "{env:ACME_MAILER_URL}/outbox?ref={invoice_id}") &&
          echo "$out" | grep -q '"to"' && { echo "$out"; exit 0; }
        sleep 1
      done
      echo "no email for invoice {invoice_id} after 10s" >&2; exit 1
    capture: { message_id: "$.items[0].id" }
    expect: { exit: 0 }
  - intent: the email is addressed to the invoice's customer
    run: curl -fsS "{env:ACME_MAILER_URL}/messages/{message_id}" | grep -q 'Globex'
    expect: { exit: 0 }
finally:
  - intent: remove the invoice
    method: DELETE
    path: /invoices/{invoice_id}
    bearer: "{token}"
```
The mailer endpoints are Acme's; use whatever your receiving service exposes. Quote capture paths that contain `[0]`.

**4. Wait for async work by polling.** Emails, queues, webhooks your service sends out, background jobs: loop with a short sleep and a deadline, as above, and print why on the last line when time runs out. A fixed `sleep 30` is slow when the system is fast and flaky when it is slow. A webhook *into* your service is an ordinary HTTP step: POST your provider's sample payload to your webhook path on the target.

**5. Check a database or a CLI the same way.** Read-only, against dev:
```yaml
  - intent: the database row agrees that the invoice was sent
    run: psql "{env:ACME_DB_URL}" -tAc "select status from invoices where id = '{invoice_id}'" | grep -qx sent
    expect: { exit: 0 }
```
Anything scriptable fits: a CLI, a queue inspector, a log grep. Review `run:` steps written by others before running them: they execute on your machine.

**6. Drive the web app with `browser:` steps.** A browser step is one action: `open` a URL, `click` a selector or text, `type` text `into` a selector, and optionally `expect_text` on the resulting page. Gate the journey with `capability: [browser]` so it **SKIPs** honestly where no driver is set up.
```yaml
id: SEND_FROM_THE_WEB_APP
kind: epic
outcome: "a freelancer can send an invoice from the web app, not just the API"
success: "the page shows Sent after Sam presses the button"
covers: [send-integrity, activation]
capability: [browser]
conflicts: tenant
steps:
  - use: create_draft_invoice
  - intent: Sam opens the login page
    browser: { open: "{env:ACME_WEB_URL}/login", expect_text: "Log in" }
  - intent: Sam types the email
    browser: { type: "{email}", into: "#email" }
  - intent: Sam types the password
    browser: { type: "{pass}", into: "#password" }
  - intent: Sam presses Log in
    browser: { click: "button[type=submit]", expect_text: "Invoices" }
  - intent: Sam opens the draft and presses Send
    browser: { open: "{env:ACME_WEB_URL}/invoices/{invoice_id}", click: "Send", expect_text: "Sent" }
finally:
  - { intent: remove the invoice, method: DELETE, path: "/invoices/{invoice_id}", bearer: "{token}" }
```
uj does not ship a browser. You point it at a driver with one of:

| variable | driver | contract |
|---|---|---|
| `UJ_BROWSER_CMD` | `command` | uj runs it with `bash -c` per step, writes `{"open","click","type","into","expect_text"}` as JSON on stdin; it prints `{"ok": true, "text": "<page text>"}` (or `"error"`) |
| `UJ_BROWSER_URL` | `http` | uj POSTs the same JSON there and reads the same reply |
| `UJ_BROWSER_DRIVER` | `command` or `http` | picks one explicitly when both are set |

The command driver is a fresh process per step, so your driver must keep the browser session alive between calls (for example, attach to a browser it started earlier).

**7. Keep one pack per service, plus a small cross-service pack.** Each pack is its own uj project (`uj init --here` in its folder, SOP 04 step 11) with its own `harness.toml`, `environment.json`, `.uj/` and `journeys/`:
```
acme/
  invoicer-tests/      target: invoicer   (most journeys live here)
  mailer-tests/        target: mailer     (the mailer's own API journeys)
  e2e/                 target: invoicer   (the few stories that cross services, via run: and browser:)
```
uj finds the right `harness.toml` from the path you give it, so `uj run e2e/journeys/` uses the e2e pack's target from anywhere. Keep the cross-service pack small: it is the slowest and most fragile.

**8. Services on the ab0t mesh.** Getting sign-in or service keys for a mesh service is Ally's job: [`../authmesh/`](../authmesh/00_index.md). Use the key in journeys through `{env:NAME}`.

**9. Check it offline.**
```sh
uj explain e2e/journeys/
uj lint e2e/journeys/
uj validate e2e/journeys/
```

## What you'll see

`uj explain` on the browser journey adds `Requires capability: browser` under the story header; `run:` and `browser:` steps read like any other step. In a run, a `run:` step's line shows `RUN` and its exit code where an HTTP step shows method and status. Without a driver the browser journey prints `SKIP` with the reason `capability absent: browser`. `uj validate e2e/journeys/` ends `validate: 2 ok, 0 invalid`.

## If it goes wrong

- `run exit 1, wanted 0 — <first line of the output>` — the command failed; the first line is usually your own message (`no email for invoice …`).
- `run capture failed: no value at $.items[0].id (the command must emit JSON on stdout to capture from it)` — print only the JSON on stdout; send chatter to stderr only on failure.
- `run failed to start: …` — no `bash` on that machine.
- `environment variable ACME_MAILER_URL is not set (referenced as {env:…}) — export it, or set it in your CI secrets` (VOID) — export it, or map it from the CI secret store. A plain `$NAME` inside the command is not checked by uj; use `{env:NAME}`.
- The other service is down and the `run:` step FAILs — uj sees only the command's exit code, so it cannot tell "mailer down" from "no email". Print the reason on the last line (`no email for invoice … after 10s`) and check the other service before calling it a bug.
- `no browser driver configured (set UJ_BROWSER_CMD or UJ_BROWSER_URL, or gate the journey on capability: [browser] so it SKIPs)` — add `capability: [browser]`, or set a driver.
- `command browser driver failed: driver did not return JSON {ok,text}: …` — your driver printed something other than the reply JSON.
- `browser action failed: ok=false` — the driver said it could not do the action; check its log.
- `expected page text to contain "Sent", got "…"` — the page did not change as expected: a real UI finding, or a selector that missed.
- `yaml: line N: did not find expected ',' or '}'` — quote a capture path containing `[0]`.
- The browser journey SKIPs in CI and `--strict` turns that into exit `1`: run UI journeys in their own job with a driver, or keep them in a folder the API job does not run (SOP 12).

## Coming

- **Multi-service journeys** (a named target per step). *Today:* one target per run; reach other services with `run:` steps and environment variables; one pack per service.
- **A built-in browser driver.** *Today:* bring one through `UJ_BROWSER_CMD` or `UJ_BROWSER_URL`.
- **Auth headers and driver settings for the `http` browser driver.** *Today:* only the three environment variables are read; put the browser service behind something that needs no header, on dev.
- **A way for a `run:` step to report VOID** (the other service is down). *Today:* an unset `{env:NAME}` is VOID; a down service is a FAIL whose last output line says why.
- **A wait/retry step** (`until:`). *Today:* a polling loop in a `run:` step.
- **A built-in webhook receiver.** *Today:* poll the service that receives the call.

## Next

SOP 11, run, read verdicts and debug. Or SOP 12 to put these in CI.
