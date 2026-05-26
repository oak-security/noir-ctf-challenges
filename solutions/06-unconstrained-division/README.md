# Solution: 06 Unconstrained Division

## Bug

In Noir, an `unconstrained fn` executes during witness generation only. It runs like normal Rust code to produce values, but contributes **zero constraints** to the proof system. From the verifier's perspective, the return values of an unconstrained function are just free witnesses that the prover can set to anything.

The circuit's constrained logic is:

```rust
assert(q * divisor + r == numerator);
assert(q == claimed_quotient);
// Missing: assert(r < divisor);
```

The [Euclidean division theorem](https://en.wikipedia.org/wiki/Euclidean_division#Division_theorem) states that for `numerator` and `divisor > 0`, the pair `(q, r)` is unique **only if** both `numerator == q * divisor + r` and `0 <= r < divisor` hold. The circuit enforces only the first condition, so any `(q', r')` satisfying `q' * divisor + r' == numerator` passes, including `(0, numerator)`.

Since the verification key is derived only from the constrained portion of the circuit, modifying the body of an `unconstrained fn` does not change the VK. The verifier has no way to detect the tampering.

## Exploit

Replace the body of `divmod` to return a malicious hint:

```rust
unconstrained fn divmod(numerator: u32, divisor: u32) -> (u32, u32) {
    (0, numerator)
}

fn main(numerator: pub u32, divisor: pub u32, claimed_quotient: pub u32) {
    // SAFETY: divmod is unconstrained; (q, r) are prover-supplied witnesses that the constraint system needs to re-validate.
    let (q, r) = unsafe { divmod(numerator, divisor) };

    assert(q * divisor + r == numerator);
    assert(q == claimed_quotient);
}
```

Then prove with:

```toml
numerator = "10"
divisor = "3"
claimed_quotient = "0"
```

- `q * divisor + r = 0 * 3 + 10 = 10 = numerator` ✓
- `q = 0 = claimed_quotient` ✓
- No `r < divisor` check, so `r = 10` passes silently.

The verification key is derived from the constrained portion of the circuit only. Editing the body of an `unconstrained fn` does not change the VK, so the verifier accepts the malicious proof.

## Fix

Add the missing remainder bound:

```diff
 assert(q * divisor + r == numerator);
+assert(r < divisor); // <- pins (q, r) to the unique non-negative solution
 assert(q == claimed_quotient);
```

The full patched circuit is in [`patched_main.nr`](./patched_main.nr).

## Additional context

This is the most common real-world Noir bug. Developers learn that unconstrained makes witness generation faster and reach for it whenever a computation looks expensive (division, square root, sorting, finding a Merkle path). They forget that "I computed it off-circuit" is not a constraint. Anything coming out of unconstrained is a prover-supplied free variable until the constrained part of the circuit pins it down.