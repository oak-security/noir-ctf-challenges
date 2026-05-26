# Challenge 07: BoundedVec Residual (Capacity vs Length)

## Setup

An issuer runs a zero-knowledge loyalty programme. A **coupon** is a byte buffer of the form:

```
USER:<id>;PTS:<7-digit points>
```

The issuer **notarizes** a coupon by publishing a commitment (a SHA-256 digest) over its bytes. To spend points, a user proves in zero knowledge that:

1. their coupon matches the issuer's notarized commitment, and
2. the public `claimed_points` equals the points written in that coupon.

The coupon is a Noir `BoundedVec<u8, N>` (`N = 64`): a fixed `storage: [u8; N]` backing array paired with a `len`. Only the first `len` bytes are active content, and the commitment `notarize(coupon)` folds **only** that active region, `storage[0..len)`.

The issuer has notarized exactly one coupon:

```
USER:guest001;PTS:0000010   ->   10 points   (len = 25)
```

## Objective

Produce a valid proof that redeems **1,000,000 points** (`claimed_points = 1000000`) while your coupon still hashes to the issuer's notarized commitment for the genuine 10-point coupon. That digest is hardcoded in the circuit (`global NOTARIZED_DIGEST`), so you cannot swap in your own; you must cheat against the real one.

## How to verify your answer

1. Generate the input file: `nargo check`. This will create a [`Prover.toml`](./Prover.toml) file.
2. Edit [`Prover.toml`](./Prover.toml) to craft your exploit. Example values (an honest 10-point redemption) can be found in the [`Prover.toml.example`](./Prover.toml.example) file.
3. Run `./verify.sh` to compile, prove, and verify.

The challenge is solved when `verify.sh` prints `SOLVED`.

> [!TIP]
> You can run `./verify.sh` with the [`Prover.toml.example`](./Prover.toml.example) values first to confirm your setup works before crafting the exploit.

## Hints

<details>
<summary>Hint 1</summary>

What bounds the index `marker`? The notarized commitment covers `coupon[0..len)`, but what range of the buffer can `marker` actually point into?

</details>


<details>
<summary>Hint 2</summary>

The backing `storage` always has `N = 64` slots; a genuine coupon uses only `len = 25` of them. Who controls `storage[len..N)`, and is any of it covered by the commitment?

</details>


<details>
<summary>Hint 3</summary>

The circuit reads bytes by indexing `coupon.storage()` (the raw `[u8; N]` backing array) instead of `coupon.get()` (which bounds the index by `len`). What can `marker` reach in `storage` that the commitment never folded?

</details>
