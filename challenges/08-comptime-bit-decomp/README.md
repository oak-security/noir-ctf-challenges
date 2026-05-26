# Challenge 08: Comptime Range Gadget

## Setup

A confidential-payment gate accepts a **note** only if its `amount` is a valid
**16-bit value** — that is, `0 <= amount < 2^16` (at most `65535`). Any larger
amount must be rejected.

This is not automatic. A Noir `Field` holds numbers astronomically larger than
`2^16`, so "fits in 16 bits" is a property the circuit has to *prove*. It does
so with the standard tool — a **bit-decomposition range check**:

- `amount` is split into 16 witness **bits**, `bits[0..16]`.
- The in-range check then *pins* those bits to `amount`, so that a satisfying
  witness can exist only when `amount` is genuinely a 16-bit number. Two
  constraints achieve this together:
  1. **recomposition** — the bits recompose to the value:
     `amount == bits[0]·2^0 + bits[1]·2^1 + ... + bits[15]·2^15`
  2. **booleanity** — every bit really is a bit:
     `bits[i] · (bits[i] - 1) == 0`, for all `i`

With both in force, the largest value the 16 bits can represent is
`1 + 2 + 4 + ... + 32768 = 2^16 - 1 = 65535`. So any note that passes the check
is provably in `[0, 65535]`, and that is exactly the 16-bit range the gate
relies on.

The range check is **not written by hand**. It is generated at compile time by
the `#[range_gadget]` attribute on the `Note` struct (see
[`src/main.nr`](./src/main.nr)), which walks the 16-bit array and assembles the
recomposition and booleanity constraints using Noir's `quote` / unquote
metaprogramming.

`amount` is a public input; `bits` is the prover's private witness.

## Objective

Produce a valid proof that the gate accepts a note with **`amount = 1000000`**
— a value that needs 20 bits and is far outside the 16-bit range — certifying
it as a valid 16-bit value. The gate is supposed to be incapable of accepting
any `amount >= 65536`; your proof must make it do so anyway.

## How to verify your answer

1. Generate the input file: `nargo check`. This will create a [`Prover.toml`](./Prover.toml) file.
2. Edit [`Prover.toml`](./Prover.toml) to craft your exploit. Example values (an honest 50000 note) can be found in the [`Prover.toml.example`](./Prover.toml.example) file.
3. Run `./verify.sh` to compile, prove, and verify.

The challenge is solved when `verify.sh` prints `SOLVED`.

> [!TIP]
> You can run `./verify.sh` with the [`Prover.toml.example`](./Prover.toml.example) values first to confirm your setup works before crafting the exploit.

## Hints

<details>
<summary>Hint 1</summary>

`bits` is the prover's witness — all 16 values are freely chosen. Of the two constraints, which
one actually limits how large `amount` can be? (Recomposition just says the
bits add up to `amount`; that alone is satisfiable for *any* `amount`.) So the
whole 16-bit bound rests on booleanity. Is it really enforced on all 16 bits?

</details>

<details>
<summary>Hint 2</summary>

Don't trust what the gadget *intends* — expand what it *generates*. Hand-run the
`comptime` `for` loop for just 3 bits and write out the body of `assert_in_range`
it produces. Count the `booleanity` asserts in the result. Then put the two
loop lines side by side:

```rust
recompose  = quote { $recompose + self.bits[$i] * $weight };
booleanity = quote { assert(self.bits[$i] * (self.bits[$i] - 1) == 0); };
```

One of these refers back to itself. The other doesn't. What happens to the
fragment that doesn't?

</details>