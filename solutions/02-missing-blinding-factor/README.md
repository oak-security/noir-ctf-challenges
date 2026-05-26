# Solution: 02 Missing Blinding Factor

## Bug

```rust
fn main(move: Field, commitment: pub Field) {
    assert((move - 0) * (move - 1) * (move - 2) == 0);
    assert(h(move) == commitment);
}
```

A commitment must be both **binding** (you cannot open it to two different values) and **hiding** (it reveals nothing about the committed value). Here the commitment is `h(move)` with no blinding factor, over a three-element message space `{0, 1, 2}`. It is binding if `h` is collision-resistant, but it is **not hiding** — crucially, the strength of `h` is irrelevant: even a perfect, collision-resistant hash leaks an input drawn from a domain this small. An attacker precomputes the only three possible commitments and matches the published value to recover the move.

The practical consequence is that a player can backrun the commit phase: read the opponent's published commitment, brute-force their move, and commit the winning counter — winning every round.

## Exploit

Brute-force the three possible moves against the opponent's published commitment `29`:

- `h(0) = 0 + 0 + 11 = 11`
- `h(1) = 1 + 7 + 11 = 19`
- `h(2) = 4 + 14 + 11 = 29`  ← match

So `move = 2` opens commitment `29`:

```toml
move = "2"
commitment = "29"
```

`h(2) = 29 = commitment`, so the circuit accepts. The opener has no relationship to whoever published `29`; they just enumerated the message space.

## Fix

Bind a high-entropy blinding factor (a "salt") into the commitment, so that brute-forcing the joint `(move, salt)` space is infeasible:

```diff
-fn main(move: Field, commitment: pub Field) {
+fn main(move: Field, salt: Field, commitment: pub Field) {
     assert((move - 0) * (move - 1) * (move - 2) == 0);
-    assert(h(move) == commitment);
+    assert(h2(move, salt) == commitment); // <- FIXED: bind a secret salt so the commitment is hiding
 }
```

With `salt` drawn from a large random distribution (say, 256 bits), the commitment is now hiding. The full patched circuit is in [`patched_main.nr`](./patched_main.nr). It adds a `salt` input, so it has a different interface than the challenge: copy it over `challenges/02-missing-blinding-factor/src/main.nr` to compile it, but it will not run against this challenge's `verify.sh` / `Prover.toml.example` (those target the unsalted version). To exercise it, supply `move`, a random `salt`, and `commitment = h2(move, salt)`.

Some additional notes:

- Use a hash that is collision-resistant in both arguments (e.g. Poseidon over `[move, salt]`).
- Draw `salt` from a CSPRNG. Predictable salts (timestamps, counters) defeat hiding.
- For interactive protocols, also bind the player's identity / round into the commitment to prevent commitment-replay: `h(move, salt, player_id)`.

## Additional context

Whenever a circuit accepts a commitment input and an opening, ask:

1. Is the commitment hiding even when the message space is small? If not, you need a salt with enough entropy.
2. Is every "blinding" parameter actually wired into a hash constraint? Declared-but-unused parameters are the canonical form of this bug.
3. Does the commitment need to be bound to the committer's identity (and/or session/round)? If so, hash those in too.

Real-world analogues: any reveal-style scheme over a small message space, such as sealed-bid auctions with discrete bid increments, voting over a small candidate set, and commit-reveal randomness with predictable inputs (early Ethereum RANDAO designs had a related bias when the commitment space was small).

Audit shortcut: for any commitment scheme, check that a high-entropy blinding factor (salt) is actually hashed into the commitment — a salt that is missing, or merely declared and never constrained, is the tell.
