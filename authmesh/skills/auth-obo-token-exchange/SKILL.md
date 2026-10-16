---
name: auth-obo-token-exchange
description: >-
  Let an app or agent call another ab0t mesh service on behalf of a signed-in person (on-behalf-of,
  OAuth 2.0 Token Exchange, RFC 8693), with the call attributed to "app A acting for person U" and
  limited to what U holds and granted. Use when a client wants to "set up OBO", "act for a user",
  "token exchange", get an actor token, create a may_act / delegation grant, use auth-sdk-go TokenFor
  or ExchangeToken, run `authsetup obo-actor` / `obo-enable` / `obo-disable`, or debug invalid_target,
  invalid_scope, invalid_request / invalid_grant, invalid_client on the token endpoint.
---

# On-behalf-of: your app acting for a signed-in person

## What this is

Sometimes your app (or an agent) must call another mesh service *as the person using it*: read their
documents, list their projects. Token exchange gives your app a short-lived token for that one
service, carrying the person as the subject and your app as the actor, limited to what the person
holds and agreed to, so the other service can enforce and audit it without ever seeing the person's
own token.

## The picture

```
person U ──signs in──► your app A ──TokenFor(B, scope, U's session)──► auth  /auth/oauth/token
                                                                         │ checks: A is A, U's token is valid,
                                                                         │ U granted A this scope, B is a known audience
                         A ──Bearer <delegated token>──► service B ◄─────┘ (~15 min, no refresh token)
```

| piece | what it is | made by |
|---|---|---|
| A's identity | a confidential OAuth client + a service account (the **actor id**) in the org whose resource A calls | `authsetup obo-actor` (once) |
| U's grant | "A may act for me, read-only, these permissions", created with U's own token | `authsetup obo-enable`, or `GrantDelegation` in the SDK (once per person) |
| the audience | B's registered service audience on that org, or `SELF:<org id>` | fixed when the org was created |
| the token | delegated, scoped, ~15 minutes | `TokenFor` per request (cached) |

Two calls, one API: `TokenFor(ctx, resource, scope, nil)` gets a token for **A as itself** (client
credentials); `TokenFor(…, session)` gets one **for person U** (token exchange).

## Do this (the default path, Go, `auth-sdk-go` v0.12.1+)

1. **Give A its identity**, as an admin of the org whose resource A will call (dev first):
   ```sh
   authsetup --env dev obo-actor --dry-run
   authsetup --env dev obo-actor --actor-scope <service>.<resource>.read
   ```
   It prints the service account's **user id** (the actor id), the client id and the client secret
   (shown **once**; store it in your secrets manager). `--org <org id>` targets another org; `--rotate`
   re-mints the secret (the client id changes); `--disable` revokes it.
2. **Each person grants A once**, with their own token, from a session in that same org:
   ```sh
   authsetup --env dev obo-enable --actor <actor id> --audience <B> --scope <service>.<resource>.read \
     --subject-token "$U_TOKEN" --dry-run          # then again without --dry-run
   ```
   or in your app: `c.GrantDelegation(ctx, auth.DelegationGrant{ActorID: actorID, Scope: []string{"…"}}, personToken)`.
   `obo-enable` accepts read-only permissions only (ending in `read`, `list`, `get`, `view`, `describe`,
   `show` or `search`; no wildcards) and refuses if B is not that org's audience. Revoke with
   `authsetup --env dev obo-disable --actor <actor id> --subject-token "$U_TOKEN"`.
3. **Per request**, get a token and call B:
   ```go
   c := auth.New(authURL,
       auth.WithClientCredentials(clientID, clientSecret),   // A's client, sent as HTTP Basic
       auth.WithLegacyActorExchange("<B's audience>"),        // today's exchange shape; delete when the service accepts the target shape
   )
   tok, err := c.TokenFor(ctx, "<B's audience>", "<service>.<resource>.read", auth.StaticSession(personToken))
   if err != nil { /* see the table below; never treat an error as allowed */ }
   req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
   ```
   Tokens are cached until 30 s before expiry, so call `TokenFor` per request. Never forward a token
   you received to another service; get your own. The raw form is `ExchangeToken` (with an actor token
   from `OAuthToken` client credentials); prefer `TokenFor`.

The full wire contract and a runnable program: the SDK repository's `docs/OBO_TOKEN_EXCHANGE.md` and
`examples/obo` (`https://github.com/ab0t-com/auth-sdk-go`).

## What your customers notice

- They approve once (the grant), can revoke any time, and B's audit trail shows "A acting for U".
- A can only ever do what U holds **and** granted **and** A asked for; anything wider is refused, not
  silently granted. A token lives about 15 minutes; asking again re-checks everything, so a revoked
  grant stops working on the next request.
- A grant is per org: a person who works in several orgs grants in each one separately.

## Common mistakes (and what you will see)

| wire answer | `TokenFor` returns | meaning | fix |
|---|---|---|---|
| `400 invalid_request` or `invalid_grant` | `ErrReauthenticate` | U's token was not accepted (expired, revoked, not for your app, left the org), or on today's exchange shape: no grant from this person | sign them in again, retry once; check step 2 |
| `400 invalid_target` | `ErrNoConnection` | B is not an audience this org recognises (its registered service audience, or `SELF:<org id>`) | use the right audience; it is fixed at org creation |
| `400 invalid_target` + `"suberror":"consent_required"` | `*ConsentRequired` | U can approve | send them to `consent.AuthorizationURL(…)`, then retry |
| `400 invalid_scope` | `ErrScopeNotAllowed` | asked for more than the grant or client allows | ask for less |
| `401 invalid_client` | `ErrClientAuth` | wrong client id / secret | fix, or `obo-actor --rotate` |
| `400 unauthorized_client` | `ErrClientNotEnabled` | client not registered for that grant | re-run `obo-actor` |
| 5xx, 429, network | `ErrUnavailable` | could not decide | back off; never allow |

`obo-enable` messages: `"invalid_target: the subject org mints aud=X"` (B is not that org's audience;
it cannot be changed), `"scope ... is not read-only"`, `"provide the subject's authentication"`. A grant
created from a session in a child or workspace org is accepted but never used: switch to the right org
first (`SwitchOrganization`). A granted scope of `*` means a privileged actor; do not build on it.

## Check it worked

`authsetup --env dev obo-enable … --dry-run` should say the covering grant already exists (re-runs are
no-ops). Then one `TokenFor` call returns a token whose `Scope` is what you asked for, and B answers
`200`. Test your error handling with `authclienttest.NewTokenEndpoint()` from the SDK. Still stuck:
the wire `error` / `suberror`, the audience and org id you used (never a token or secret) to
`platform-team@ab0t.com`.
