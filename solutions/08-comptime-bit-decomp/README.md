# Solution: 08 Comptime Range Gadget (Quote-Accumulation Bug)

## Bug

The 16-bit range check is generated at compile time by the `#[range_gadget]` attribute. A correct bit-decomposition range proof has two halves:
**recomposition** (`amount == sum(bits[i] * 2^i)`) and **booleanity**
(`bits[i] * (bits[i] - 1) == 0` for every bit). 

The generator builds both, but it builds them differently:

```rust
comptime fn range_gadget(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    let mut recompose = quote { 0 };
    let mut booleanity = quote {};
    let mut weight: Field = 1;
    for i in 0..16 {
        recompose  = quote { $recompose + self.bits[$i] * $weight };               // accumulates: keeps $recompose
        booleanity = quote { assert(self.bits[$i] * (self.bits[$i] - 1) == 0); };   // OVERWRITES: no $booleanity
        weight = weight * 2;
    }
    quote {
        impl $typ {
            fn assert_in_range(self) {
                $booleanity
                assert(self.amount == $recompose, "amount out of 16-bit range");
            }
        }
    }
}
```

The difference is in the self-reference:
- `recompose` **accumulates**: its right-hand side includes `$recompose`, so each iteration appends to the previous value. After 16 iterations, it holds the full 16-term sum. 
- `booleanity` does **not accumulate**: its right-hand side is a bare `quote { assert(...) }` with no `$booleanity`, so each iteration *overwrites* the variable instead of appending
to it. After the loop, `booleanity` retains only the **last** iteration's
constraint, which is `bits[15]`.

The generated method is therefore:

```rust
impl Note {
    fn assert_in_range(self) {
        assert(self.bits[15] * (self.bits[15] - 1) == 0);   // the ONLY booleanity check
        assert(self.amount ==
            self.bits[0]*1 + self.bits[1]*2 + ... + self.bits[15]*32768);
    }
}
```

Only `bits[15]` is forced to be a real bit; `bits[0..15]` are 15 free field
elements.

### Debugging the generated code

A `comptime fn` runs during `nargo compile`, so its output can be inspected directly: `println` the `Quoted` it assembles and read the generated code straight from the compiler output. Bind the returned quote to a variable, print it, then return it:

```rust
let generated = quote {
    impl $typ {
        fn assert_in_range(self) {
            $booleanity
            assert(self.amount == $recompose, "amount out of 16-bit range");
        }
    }
};
println(f"{generated}");   // prints at compile time -- remove afterwards
generated
```

`nargo compile` then prints the assembled function — a single booleanity check
(`bits[15]`) followed by the full 16-term recomposition — making the bug
directly visible. The output is space-separated (`self . bits [ 15 ]`) because
a `Quoted` is a token stream, not text; it still means `self.bits[15]`.
Alternatively, hand-running the loop for 2–3 bits reaches the same conclusion:
`recompose` carries `$recompose` and grows, `booleanity` omits `$booleanity`
and resets.

### Why the surviving recomposition is insufficient

The surviving `amount == sum(bits[i] * 2^i)` is still enforced, and the proof
fails if it doesn't hold. But it does not bound `amount`, and understanding why
is the key to the bug.

A bit-decomposition range proof needs two constraints working *together*:

| | constraint | what it actually buys you |
|---|---|---|
| 1 | `amount == Σ bits[i]·2^i` | ties `amount` to the bits (still enforced ✓) |
| 2 | every `bits[i] ∈ {0, 1}` | bounds each term → bounds the sum → bounds `amount` |

The ceiling `amount < 2^16` lives **entirely in constraint 2**: only if every
bit is `0` or `1` is the sum capped at `1 + 2 + 4 + ... + 32768 = 65535`.
Constraint 1 on its own says *nothing* about magnitude — it only says `amount`
equals *some* weighted combination of 16 prover-chosen values. Since the bits
are witness inputs, the prover can solve that single equation for *any*
`amount`: with `bits[0]` free and weight `1`, the trivial solution is
`bits[0] = amount`, all other bits `0`.

So the overwrite did not break the sum-match — it deleted the **bound**. A sum
constraint over *unbounded* addends does not bound the total; booleanity is the
load-bearing half, and 15 of its 16 constraints were silently discarded.

This is a quote-accumulation bug, and it is specific to metaprogramming: when
you assemble constraints by folding them into a `Quoted` across a loop, every
step must chain onto its own previous value (`x = quote { $x ... }`). Drop the
`$x` and the accumulator silently keeps only the last fragment. There is no
"forgotten token buffer" to make this mistake in hand-written code. The tell is
that `recompose` and `booleanity` are accumulated *differently* in the same
loop.

## Exploit

Put the entire `amount` into a free coefficient and leave the rest zero,
making sure the one constrained bit (`bits[15]`) stays a real bit:

```toml
amount = "1000000"
bits = ["1000000", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"]
```

- Recomposition (constraint 1): `1000000·1 + 0·2 + ... + 0·32768 == 1000000 == amount`,
  so it holds ✓. The sum-match passes because it never bounded `amount`.
- The only surviving booleanity check (constraint 2) is on `bits[15] = 0`:
  `0 * (0 - 1) == 0`. ✓
- `bits[0] = 1000000` is one of the 15 unconstrained coefficients, so nothing
  rejects it for being a non-bit. ✓

The gate certifies `1000000` (a 20-bit value) as a valid 16-bit denomination.
By contrast, putting the value in the constrained slot (`bits[15] = 1000000`) is
correctly *rejected*, which confirms exactly one booleanity constraint survives.

## Fix

Accumulate `booleanity` the same way `recompose` is accumulated. Prepend
`$booleanity` so each bit's constraint is kept, not overwritten:

```diff
     for i in 0..16 {
         recompose = quote { $recompose + self.bits[$i] * $weight };
-        booleanity = quote { assert(self.bits[$i] * (self.bits[$i] - 1) == 0, "bit is not boolean"); };
+        booleanity = quote {
+            $booleanity // <- FIXED: prepend `$booleanity` so the per-bit checks accumulate instead of overwriting
+            assert(self.bits[$i] * (self.bits[$i] - 1) == 0, "bit is not boolean");
+        };
         weight = weight * 2;
     }
```

With all 16 booleanity constraints emitted, every `bits[i]` is `0` or `1`, so
`sum(bits[i] * 2^i)` lies in `[0, 65535]` and the recomposition forces `amount`
into that range. The exploit's `bits[0] = 1000000` now fails
`1000000 * 999999 == 0`, while the honest 50000 note (with real bits) still
verifies.

The full patched circuit is in [`patched_main.nr`](./patched_main.nr). To
compile or test it, copy it over
`challenges/08-comptime-bit-decomp/src/main.nr` and run `./verify.sh` from
there.

## Additional context

Bug class: **under-constrained bit decomposition** (a range proof that
recomposes the value but fails to bind the bits to `{0, 1}`), here caused by a
**quote-accumulation error**, specifically the missing `$booleanity` self-reference.

The metaprogramming is the root cause, not just a wrapper: the bug exists
*because* the constraints are folded into a `Quoted` accumulator, and it could
not arise in a hand-written loop (`for i in 0..16 { assert(...); }` emits every
iteration unconditionally). When auditing comptime code generators:

- For every accumulator pattern `x = quote { ... }` inside a `comptime` loop,
  confirm the right-hand side references `$x`. An assignment that doesn't is a
  silent reset that discards all prior iterations — keeping only the last.
- When two fragments are built in the same loop (here `recompose` and
  `booleanity`), check that they are accumulated *consistently*. A divergence
  is the tell.
- Read the *generated* constraints, not just the generator: enumerate what the
  unrolled `assert_in_range` actually contains and compare it to what a correct
  range gadget must contain (recomposition **and** booleanity for every bit).
- Prefer std primitives (`amount.to_le_bits()` / `assert_max_bit_size`) over a
  hand-rolled or generated decomposition, since they bundle booleanity in.

References:

- Noir [metaprogramming: quote / unquote](https://noir-lang.org/docs/noir/concepts/comptime)
  — `quote { $x ... }` splices the current value of `x`; an accumulator must
  reference itself to grow.
