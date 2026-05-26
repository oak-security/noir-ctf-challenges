# Solution: 01 Missing Constraint

## Bug

```rust
let _check = computed == expected_hash;  // expression, not constraint
```

The `==` operator in Noir returns a `bool` but does **not** add a constraint. The circuit effectively compares `computed` to `expected_hash` and discards the result. This means that the constraint system never enforces the relation, allowing users to provide any value for `secret` and still produce a valid proof.

## Exploit

```toml
secret = "0"
expected_hash = "74844"
```

Supplying the above input to the patched circuit will fail because `password_hash(0) = 42 != 74844`. However, in the original buggy circuit, any value of `secret` would produce a valid proof because no constraint ties `secret` to `expected_hash`.

## Fix

Replace the discarded comparison with `assert`:

```diff
-    let _check = computed == expected_hash;
+    assert(computed == expected_hash); // <- FIXED: assert enforces the constraint
```

The full patched circuit is in [`patched_main.nr`](./patched_main.nr).

## Additional context

Every Noir circuit should be reviewed by checking that every code path that introduces a witness has an `assert` that constrains it. If a witness flows into computation but never into an `assert`, the prover controls it.

This is the canonical Noir / ZK footgun. Computing a value inside a circuit does not mean the value is constrained. Anything the prover supplies including witness values that drive a "computed" result is under their control unless an `assert` (or another constraint-producing construct) ties them down.