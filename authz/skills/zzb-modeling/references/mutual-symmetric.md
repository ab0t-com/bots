# Mutual / symmetric relations (friends, connections)

**Denormalize the inverse.** A relation is DIRECTIONAL and there is no inverse
traversal, so "A and B each follow the other" can't be computed from one tuple.
Store BOTH directions and intersect:
```json
{"type":"user","relations":{
   "follower":{"allowed_subject_types":["user"]},   // people who follow me
   "outgoing":{"allowed_subject_types":["user"]}},  // people I follow (the inverse index)
 "permissions":{"mutual":"follower & outgoing"}}
```
Write every follow as a PAIR, atomically, so the two never diverge:
```sh
# alice follows bob  → forward on bob, reverse on alice
zzb transact --write user:bob#follower@user:alice --write user:alice#outgoing@user:bob
```
`mutual` is ALLOW only when both tuples exist (a real two-way friendship). **Critical:**
your app MUST write AND delete both sides together (use `transact`) — an unfollow that
drops only one side leaves a stale friendship. For friend-of-friend, materialize a
symmetric `friend` relation (the arrow's left side must be a stored *relation*, not the
`mutual` permission) and use `fof: friend + friend->friend`. (A first-class reverse
traversal is on the roadmap; until then, this denormalization is the way.)

*See also: this is a two-sided pattern like the Chinese wall (conditional-gates §5),
but built from a denormalized inverse + `&`, not from mutual exclusion.*
