# Service Registration Reference

## Register with `authsetup`

Register your service with the `authsetup` CLI (public repo: https://github.com/ab0t-com/clientsetup). It reads `config/permissions.json` and, in one idempotent run, creates:

- your **service org** (its slug is your service id, e.g. `myservice`),
- a dedicated **admin account** for that org, with a **randomly generated password**,
- your permission list in the shared registry (owned by your service org),
- your **service key** (`<service>-internal`) holding every permission you declared,
- optionally your sign-in client, login page and the org your end users land in.

Everything it creates is saved, mode `0600`, under `~/.authmesh/<service>/`, one file per environment (`<service>.dev.json`, `<service>.prod.json`, ...). Nothing is derived from your service name, so nobody can guess your admin login. Never commit those files and never delete the folder (it holds every environment, prod included).

```sh
# install once (checks the published sha256)
curl -fsSL https://raw.githubusercontent.com/ab0t-com/clientsetup/main/install.sh | sh
authsetup version

# check your config offline, then preview and apply on dev
authsetup --config-dir ./config validate
authsetup --env dev --config-dir ./config up --dry-run
authsetup --env dev --config-dir ./config up

# later, the same files against production
authsetup --env prod --config-dir ./config up --dry-run
authsetup --env prod --config-dir ./config up
```

`prod` is the default environment when you give no `--env`, so always pass `--env`. Re-running is safe: when everything matches it says so and changes nothing.

Step by step, with the exact messages: authmesh SOPs 03 (install, environments), 04 (`permissions.json`), 05 (first run) — https://github.com/ab0t-com/bots/tree/main/authmesh

## Getting the values into your service

```sh
authsetup --env dev settings                   # prints backend + frontend values; the key is masked
authsetup --env dev settings --env-file .env   # writes AB0T_AUTH_URL, AB0T_AUTH_AUDIENCE, AUTH_SERVICE_KEY, ... (mode 0600)
authsetup --env dev info                       # which file holds what
```

Your **audience** is `service.audience` from `permissions.json` (keep it equal to `service.id`). It is fixed when your org is created. See authmesh SOP 06.

## Finding and granting permissions

### List registered services and valid permissions

```bash
curl -s "$AUTH_URL/permissions/registry/services" | jq '.services[].service'

curl -s "$AUTH_URL/permissions/registry/valid-permissions" | \
  jq '.permissions | map(select(startswith("myservice.")))'
```

### Grant a permission to a user (ordinary, `org`-scope permissions)

Sign in as your service admin (email and password are in `~/.authmesh/<service>/<service>.<env>.json`; never paste them into chat), scoped to the org, then:

```bash
curl -X POST "$AUTH_URL/permissions/grant?user_id=$USER_ID&org_id=$ORG_ID&permission=myservice.admin" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Or put the user in a team that carries the permission. A newly granted permission shows on the user's next fresh login (or within about five minutes).

### Revoke a permission

```bash
curl -X POST "$AUTH_URL/permissions/revoke?user_id=$USER_ID&org_id=$ORG_ID&permission=myservice.admin" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### `platform`-scope (cross-customer) permissions

Permissions marked `"scope": "platform"` (e.g. `myservice.cross_tenant`) are never handed out by roles, teams or defaults. Your service admin grants them one person at a time, with a reason:

```sh
authsetup --env dev grant-platform dana@yourcompany.example myservice.cross_tenant --reason "support rota" --dry-run
authsetup --env dev grant-platform dana@yourcompany.example myservice.cross_tenant --reason "support rota"
authsetup --env dev revoke-platform dana@yourcompany.example myservice.cross_tenant --reason "left the rota"
authsetup --env dev platform-holders
```

See authmesh SOPs 01 (scope model) and 10 (your team and platform permissions).

### Check a user's or key's permissions

```bash
# A user token
curl -s -X POST "$AUTH_URL/auth/validate-token" \
  -H "Content-Type: application/json" \
  -d '{"token": "'"$USER_TOKEN"'", "expected_audience": "myservice"}' | jq '.permissions'

# An API key
curl -s -X POST "$AUTH_URL/auth/validate-api-key" \
  -H "Content-Type: application/json" \
  -d '{"api_key": "'"$API_KEY"'"}' | jq '.permissions'
```

## API keys

- **Your service key** is minted by `authsetup` with every permission you declared. Check it with `authsetup --env dev doctor` (it reports `UNDER-PERMISSIONED` if the key holds fewer permissions than your config declares).
- **A key's permissions are fixed when it is minted.** Granting something later does not flow into existing keys. If a key lacks a permission, mint a new one, roll it out, then revoke the old one (authmesh SOP 14).
- **Calling another mesh service** (billing, payment, ...): become its consumer with `authsetup --env dev connect <provider> --as <your-service>`. You get your own scoped key, saved `0600` to `~/.authmesh/<service>/<provider>-consumer.<env>.json`, which you send as `X-API-Key`. Never forward a user's bearer token to another service. See authmesh SOP 11.

### List / revoke keys

```bash
# List (as an org admin)
curl -s "$AUTH_URL/api-keys/" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.[].name'

# Revoke (irreversible; anything still using the key gets 401 at once)
curl -X DELETE "$AUTH_URL/api-keys/$KEY_ID" -H "Authorization: Bearer $ADMIN_TOKEN"
```
