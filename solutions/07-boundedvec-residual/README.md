# Solution: 07 BoundedVec Residual (Capacity vs Length)

## Bug

```rust
global NOTARIZED_DIGEST: [u8; 32] = [ /* the issuer's published 10-point digest */ ];

fn main(coupon: BoundedVec<u8, 64>, marker: u32, bound_points_digits: [u8; 7],
        claimed_points: pub u32) {
    assert(notarize(coupon) == NOTARIZED_DIGEST);              // sha256 over storage[0..len)

    let storage = coupon.storage();                            // raw [u8; 64] backing array
    let tag = pts_tag();
    for k in 0..tag.len() {
        assert(storage[marker + k] == tag[k]);                 // indexed by capacity N, not len
    }
    let from_index = marker + tag.len();
    for i in 0..PD {
        assert(storage[from_index + i] == bound_points_digits[i]);
    }
    assert(parse_points(bound_points_digits) == claimed_points);
}
```

The coupon is a `BoundedVec<u8, 64>` — a `storage: [u8; 64]` backing array plus a `len`. The commitment `notarize(coupon)` folds only the active `storage[0..len)`. But the circuit reads the bytes by calling `coupon.storage()` and indexing the raw backing array, so an index is bounded only by the static capacity `N = 64`, **not** by the dynamic `len`. The residual `storage[len..N)` is therefore free, un-notarized data.

A circuit-input `BoundedVec` is never normalized: it is deserialized straight from the witness — `storage` and `len` are both prover-supplied, with no constructor run (equivalent to `BoundedVec::from_parts_unchecked`, which, unlike `from_parts`, does not zero the residual `[len, MaxLen)`). `BoundedVec::get(i)` *does* bound `i` by `len` and would reject a residual read — but indexing `.storage()[i]` does not. **Indexing `.storage()` is the bug.**

Point `marker` into the residual: the tag-presence check still passes (the index is `< N`), and `from_index` lands past `len`. The binding loop then ties `bound_points_digits` to `storage[from_index..from_index + PD]` — bytes in the **un-notarized residual** that the prover fully controls, so the binding proves nothing about the genuine coupon. Meanwhile the commitment over `[0, len)` is unchanged, so it still matches the issuer's published digest.

## Exploit

Keep `storage[0..25)` equal to the genuine notarized coupon (so the digest is unchanged), and plant a second `;PTS:1000000` inside the residual at index 30:

```toml
marker = "30"                                    # tag in the residual; from_index = 35
bound_points_digits = ["49","48","48","48","48","48","48"]   # "1000000"
claimed_points = "1000000"

[coupon]
len = "25"
# storage[0..25)  = "USER:guest001;PTS:0000010"  (genuine -> digest unchanged)
# storage[30..42) = ";PTS:1000000"               (planted in the un-notarized residual [25, 64))
storage = ["85", "83", "69", ... ]               # full array in this folder's Prover.toml
```

- `notarize(coupon)` hashes only `storage[0..25)` → equals the issuer's published digest. ✓
- The `;PTS:` tag is found at `marker = 30` (`storage[30..35]`, index `< 64`, so the raw access is legal). ✓
- `from_index = 35`, so the binding checks `storage[35..42] == bound_points_digits` — but `[35, 42)` is the un-notarized residual where we planted `1000000`, so it just binds against our own attacker-controlled bytes. ✓
- `parse_points("1000000") == claimed_points` → `1000000 == 1000000`. ✓

The verifier accepts a proof redeeming 1,000,000 points against a coupon worth 10. The full exploit inputs are in [`Prover.toml`](./Prover.toml).

## Fix

Read the coupon through `BoundedVec::get()`, which bounds the index by the active `len`, instead of indexing the raw `.storage()` backing array (bounded only by the static capacity `N`). Every access then stays inside the notarized region `[0, len)`, and a read into the residual is rejected:

```diff
-let storage = coupon.storage();
 let tag = pts_tag();
 for k in 0..tag.len() {
-    assert(storage[marker + k] == tag[k], "no ;PTS: tag at marker");
+    assert(coupon.get(marker + k) == tag[k], "no ;PTS: tag at marker"); // .get() bounds by len, not N
 }
 let from_index = marker + tag.len();
 for i in 0..PD {
-    assert(storage[from_index + i] == bound_points_digits[i], "points binding mismatch");
+    assert(coupon.get(from_index + i) == bound_points_digits[i], "points binding mismatch");
 }
```

The full patched circuit is in [`patched_main.nr`](./patched_main.nr). It uses the `sha256` dependency, so to compile or test it, copy it over `challenges/07-boundedvec-residual/src/main.nr` (which carries the `Nargo.toml` and dependencies) and run `./verify.sh` from there.

## Additional context

A circuit-input `BoundedVec` is not normalized — treat it as `BoundedVec::from_parts_unchecked`. Read it through `.get()` (length-checked) and never index `.storage()` past `len`: the residual `storage[len..MaxLen)` is adversarial. If you must touch the backing array directly, constrain the `storage`↔`len` relationship yourself (assert indices `< len`, or scrub/commit the residual). The type system does not do it for you.

Bug class: **under-constrained buffer capacity (BoundedVec `len` vs `MaxLen`)** — every bound, index, and trust decision must be over the dynamic `len`, never the static capacity `N`.

References:

- [Noir BoundedVec](https://noir-lang.org/docs/noir/standard_library/containers/boundedvec)
- `BoundedVec::from_parts` zeros the residual `[len, MaxLen)`; `from_parts_unchecked` does not — and a circuit-input `BoundedVec` is deserialized with no constructor run, so the residual is attacker-controlled unless the circuit constrains it.
