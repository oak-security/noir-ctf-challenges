# Challenge 10: Non-Canonical Foreign-Field Encoding

## Setup

A token-claim protocol enrolls users by a Pedersen commitment to a per-user secret scalar `s` and blinding factor `r`:

```
id_i = Commit(s_i, r_i)
```

The published allowlist is `[id_0, id_1]`. To claim, a user proves they know `(s, r)` with `Commit(s, r) == id_i` for some slot `i`, and emits `nullifier = H(limbs(s))` so the registry can reject double-claims (one nullifier per enrolled identity).

The commitment is a **scalar-field Pedersen** over secp256k1's scalar field (order `n`):

```
Commit(s, r) = s * a + r * b   (mod n)
```

### Foreign fields

Aztec circuits run over BN254 (a ~254-bit prime). Arithmetic over *other* moduli (secp256k1, RSA, …) uses [`noir-bignum`](https://github.com/noir-lang/noir-bignum): a value is an array of 120-bit limbs. Limb constraints are **not** automatic; you call them explicitly, and they differ:

| | guarantees |
|---|---|
| `validate_in_range()` | each limb is 120 bits, total fits in `MOD_BITS` — limb hygiene only |
| `validate_in_field()` | **additionally** enforces `value < n` — the canonical field-element check |

The allowlist is fixed in the circuit (the enrolled users' commitments, built by `commit(s_i, r_i)`). **Slot 0** is User A's; their canonical secret and blinding are the values in [`Prover.toml.example`](./Prover.toml.example).

## Objective

You are User A: you have already claimed slot 0 honestly with your canonical secret (the values in [`Prover.toml.example`](./Prover.toml.example)). Produce a **second** valid claim for the **same** slot 0 whose emitted nullifier is **different** — defeating the one-claim-per-identity rule (a double-claim). The allowlist commitment for slot 0 is fixed, so you must collide against your *real* enrollment.

## How to verify your answer

1. Generate the input file: `nargo check`. This will create a [`Prover.toml`](./Prover.toml) file.
2. Edit [`Prover.toml`](./Prover.toml) to craft your exploit. Example values (User A's honest first claim) are in [`Prover.toml.example`](./Prover.toml.example).
3. Run `./verify.sh` to compile, prove, and verify.

The challenge is solved when `verify.sh` prints `SOLVED`.

> [!TIP]
> You can run `./verify.sh` with the [`Prover.toml.example`](./Prover.toml.example) values first to confirm your setup works before crafting the exploit.

## Hints

<details>
<summary>Hint 1</summary>

`validate_in_range()` checks limb hygiene but not `s < n`. Which integers pass it without being canonical field elements? What is the gap `[n, 2^MOD_BITS)`?

</details>


<details>
<summary>Hint 2</summary>

The commitment check is computed `mod n`. How does `Commit(s + n, r)` compare to `Commit(s, r)`? Does the allowlist check tell the two apart?

</details>


<details>
<summary>Hint 3</summary>

`==` on a `Secp256k1_Fr` is *modular* equality (it reduces mod `n`). But `get_limbs()` returns the raw limbs, and the nullifier hashes those. One logical scalar, two limb encodings, two nullifiers. You cannot build `s_A + n` with bignum addition (that reduces mod `n`); read `Secp256k1_Fr::modulus().get_limbs()` and add your secret to the low limb.

</details>
