# Solution: 05 Nullifier Malleability

## Bug

The main issue is that the `spend_tag` parameter is a free witness. There is nothing in the circuit that constrains it to a specific value. The only constraint involving `spend_tag` is the nullifier derivation itself:

```rust
assert(nullifier == hash_pair(note_secret, spend_tag as Field));
```

However, this does not prevent the bug because both `spend_tag` and `nullifier` are prover-supplied witnesses. The constraint merely enforces consistency between two free values. For a fixed `note_secret`, the prover can pick any `spend_tag` and compute the matching `nullifier`, producing a valid proof with a distinct nullifier each time. 

Consequently, this gives the prover a free knob to generate unlimited unique nullifiers for the same note.

## Exploit

```toml
note_secret = "2"
sibling = "99"
is_right = false
spend_tag = "42"
note_tree_root = "33969"
nullifier = "5397"
```

The `note_secret` and `note_tree_root` are unchanged from the honest withdrawal. Only `spend_tag` differs: `42` instead of `0`.

This produces `nullifier = hash_pair(2, 42) = 5397`, which is distinct from the honest nullifier `21`. The pool has not seen `5397`, so it accepts the withdrawal.

Repeating the exploit with different `spend_tag` values (e.g., `43, 44, 45`) allows unlimited withdrawals from the same note, draining the pool indefinitely.

## Fix

Remove `spend_tag` and derive the nullifier deterministically from `note_secret` alone:

```diff
 fn main(
     note_secret: Field,
     sibling: Field,
     is_right: bool,
-    spend_tag: u32,
     note_tree_root: pub Field,
     nullifier: pub Field,
 ) {
     ...
-    assert(nullifier == hash_pair(note_secret, spend_tag as Field));
+    assert(nullifier == note_commit(note_secret));
 }
```

Since `note_secret` is unique per note and already constrained by the Merkle inclusion proof, the nullifier is now deterministic: one note produces exactly one nullifier. This also avoids leaking the note's tree position through the nullifier, preserving user privacy.

The full patched circuit is in [`patched_main.nr`](./patched_main.nr).

## Additional context

The soundness goal for nullifiers is: every note must produce exactly one nullifier value, so the protocol's spent-set perfectly tracks consumed notes. This is broken when any witness input to the nullifier hash is not independently bound by another constraint.

The general audit rule is that for every private input that feeds into the nullifier derivation, verify that the rest of the circuit pins it to a unique value. If it isn't pinned, the prover has a free knob and can generate unlimited nullifiers per note.