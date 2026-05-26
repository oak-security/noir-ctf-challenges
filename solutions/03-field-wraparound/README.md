# Solution: 03 Field Wraparound

## Bug

In Noir, [`Field`](https://noir-lang.org/docs/noir/concepts/data_types/fields) is not an integer. It is an element of `Z / pZ` where `p` is the BN254 scalar prime (`p = 21888242871839275222246405745257275088548364400416034343698204186575808495617`). Subtraction in a finite field always produces a valid result. `10 - 1000` silently evaluates to `p - 990`. There will be no underflow, errors, or overflow flags. 

The circuit's only constraint is:

```rust
let computed = old_balance - amount;
assert(computed == new_balance);
```

This is satisfied by **any** combination of `old_balance`, `amount`, and `new_balance` whose differences agree mod `p`. There is no validation that ensures `amount <= old_balance`, so the prover can "withdraw" more than they have and the resulting `new_balance` wraps to an astronomically large field element that the bank naively trusts.

## Exploit

```toml
old_balance = "10"
amount = "1000"
new_balance = "21888242871839275222246405745257275088548364400416034343698204186575808494627"
```

The `new_balance` value is `10 - 1000 mod p = p - 990`. The constraint `old_balance - amount == new_balance` holds in the field. The bank reads `new_balance` from public inputs and credits an astronomically large value to the attacker's account.

## Fix

Cast to `u64` before subtracting. Integer arithmetic in Noir [panics on overflow/underflow](https://noir-lang.org/docs/noir/concepts/data_types/integers#overflows), so the subtraction will fail if `amount > old_balance`:

```diff
 fn main(old_balance: Field, amount: pub Field, new_balance: pub Field) {
-    let computed = old_balance - amount;
-    assert(computed == new_balance);
+    let old_balance_u64 = old_balance as u64;
+    let amount_u64 = amount as u64;
+    let computed = old_balance_u64 - amount_u64; // <- FIXED: underflow panics in u64
+    assert(computed as Field == new_balance);
 }
```

The full patched circuit is in [`patched_main.nr`](./patched_main.nr).

## Additional context

`Field` is the right type for cryptographic primitives (hash inputs, EC scalars, commitments) but the wrong type for application accounting. Any subtraction, comparison, or "this should be positive" reasoning on `Field` values must be backed by explicit range constraints.

See also: [Noir docs: Field security considerations](https://noir-lang.org/docs/noir/concepts/data_types/fields#security-considerations-for-field-arithmetic).