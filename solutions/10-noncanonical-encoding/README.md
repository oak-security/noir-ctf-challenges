# Solution: 10 Non-Canonical Foreign-Field Encoding

## Bug

```rust
fn commit(s: Secp256k1_Fr, r: Secp256k1_Fr) -> Secp256k1_Fr {
    let (a, b) = commitment_bases();
    s * a + r * b                                   // reduced mod n
}

fn main(s_limbs: [u128; 3], r_limbs: [u128; 3], claim_slot: pub u32) -> pub Field {
    let s = Secp256k1_Fr::from_limbs(s_limbs);
    let r = Secp256k1_Fr::from_limbs(r_limbs);

    s.validate_in_range();   // limb hygiene only -- NOT `s < n`
    r.validate_in_range();

    assert(commit(s, r) == allowlist()[claim_slot]);

    let l = s.get_limbs();   // RAW limbs -> nullifier
    std::hash::pedersen_hash([l[0] as Field, l[1] as Field, l[2] as Field])
}
```

`validate_in_range()` only constrains the limbs to fit `MOD_BITS` (the bit-envelope of the modulus). It does **not** enforce `s < n`. So any integer in the gap `[n, 2^MOD_BITS)` passes `validate_in_range` even though it is not a canonical field element. Since noir-bignum v0.11.0, `from_limbs()` runs this same range check automatically, so the explicit `validate_in_range()` calls add no constraints. A circuit that drops them has the same bug.

That means one logical field element has **multiple valid limb encodings**: `s` and `s + n` both pass `validate_in_range`, and they serialize to different limbs. The circuit then treats the value two inconsistent ways:

- **`==` on a `Secp256k1_Fr` is modular equality** — it reduces mod `n`, so `Commit(s + n, r) == Commit(s, r)`. The allowlist check cannot tell the encodings apart.
- **`get_limbs()` / the nullifier does not reduce** — `H(limbs(s))` and `H(limbs(s + n))` differ.

One enrolled identity, two valid claims, two distinct nullifiers → **double-claim**, defeating the registry's one-nullifier-per-user rule.

## Enrollment (how the allowlist was built)

The challenge circuit stores only the opaque commitments. The secrets behind them (kept off-chain in a real deployment) are:

| slot | user | secret `s` | blinding `r` |
|---|---|---|---|
| 0 | A | `112233445566778899001122334455` | `665544332211009988776655443322` |
| 1 | B | `998877665544332211009988776655` | `102030405060708090100203040506` |

So `allowlist[0] = commit(s_A, r_A) = [1283760567336345058482799375748290103, 162630401948933460950627, 0]`. User A's `(s_A, r_A)` are also the values in the challenge's `Prover.toml.example`; the player takes the role of User A.

## Exploit

`s_A + n` cannot be built with bignum addition (that lazily reduces mod `n`). Read the modulus's raw limbs and add the canonical secret to the low limb (`s_A` is small enough that there is no carry):

```rust
let n = Secp256k1_Fr::modulus().get_limbs();
// non-canonical sibling of User A's canonical secret s_A:
let s = Secp256k1_Fr::from_limbs([n[0] + s_a_limb0, n[1], n[2]]);
```

Concretely, for secp256k1's order `n` and User A's secret `s_A`:

```toml
# s = s_A + n  (>= n, so non-canonical; still fits MOD_BITS, so validate_in_range accepts it)
s_limbs = ["907940172456363280999134257546520632", "1329227995784915872903807060280344250", "65535"]
r_limbs = ["665544332211009988776655443322", "0", "0"]   # r = User A's blinding, unchanged
claim_slot = "0"
```

- `commit(s_A + n, r) == commit(s_A, r) == allowlist[0]` (mod `n`) → allowlist check passes. ✓
- `validate_in_range()` accepts `s_A + n` (it fits in `MOD_BITS`). ✓
- nullifier `H(limbs(s_A + n)) != H(limbs(s_A))` → a *second*, distinct nullifier for slot 0. ✓

The full exploit inputs are in [`Prover.toml`](./Prover.toml).

## Fix

Call `validate_in_field()` (which enforces `value < n`) on every foreign-field witness before trusting it. `s_A + n >= n`, so it is rejected:

```diff
 s.validate_in_range();
 r.validate_in_range();
+s.validate_in_field(); // reject non-canonical encodings: enforce s < n
+r.validate_in_field();
```

The full patched circuit is in [`patched_main.nr`](./patched_main.nr). It uses the `bignum` dependency, so to compile or test it, copy it over `challenges/10-noncanonical-encoding/src/main.nr` (which carries the `Nargo.toml` and dependencies) and run `./verify.sh` from there.

## Additional context

Bug class: **mismatched bit-lengths / non-canonical encodings in foreign-field constraints.** When a value is represented as limbs (BigNum/BigField for secp256k1, secp256r1, RSA, …), a range check on the limbs (automatic in `from_limbs()` since noir-bignum v0.11.0) does not make the value canonical. Always ask, for every foreign-field witness:

1. Is it constrained to be a *canonical* field element (`validate_in_field`), or merely limb-shaped (`validate_in_range`)?
2. Is the value ever treated two ways — reduced (`==`, arithmetic) in one place, raw (`get_limbs`, `to_bytes`, a hash/nullifier) in another? That asymmetry is what a non-canonical encoding exploits.

Audit shortcut: grep every `validate_in_range` and confirm a `validate_in_field` guards any witness whose raw limbs are later hashed, serialized, or used as an identity.
