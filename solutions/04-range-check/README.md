# Solution: 04 Range Check Omission

## Bug

In Noir, `bid as u32` does **not** constrain `bid` to fit in 32 bits. It silently truncates, returning only the lower 32 bits. The validation cap check operates on the truncated value (i.e., `bid_u32 <= max_bid`), but the commitment is computed from the original `Field`.

```rust
let bid_u32 = bid as u32;
assert(bid_u32 <= max_bid); // validates the truncated value incorrectly
let computed = commit(bid); // computes the commitment from the original value instead of truncated value
assert(computed == commitment);
```

## Exploit

```toml
bid = "4294967297"
max_bid = "100"
commitment = "18446744112364257291"
```

With the above parameters, the validation will be bypassed as follows:

```rust
let bid_u32 = bid as u32;       // bid = 4294967297, bid_u32 = 1
assert(bid_u32 <= max_bid);     // 1 <= 100 (passes)
let computed = commit(bid);     // commit(4294967297) = 18446744112364257291
assert(computed == commitment); // passes
```

Both constraints hold. However, the auction accepted a bid that is billions of times the intended cap.

## Fix

Assert that the cast does not truncate:

```diff
 let bid_u32 = bid as u32;
+assert(bid_u32 as Field == bid); // <- FIXED: ensures bid actually fits in u32
 assert(bid_u32 <= max_bid);
```

The full patched circuit is in [`patched_main.nr`](./patched_main.nr).

## Additional context

`x as u32` does not constrain `x` to be in `[0, 2^32)`. It computes a new u32 value from the low bits. To actually constrain `x < 2^32` we must add `assert(x_u32 as Field == x);` (or use a range-check builtin / dedicated library).