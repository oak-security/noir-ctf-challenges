# Challenge 04: Range Check Omission

## Setup

A sealed-bid auction with a hard cap. Bidders provide a private `bid` and publish a `commitment` derived from it. 

The auction is configured with `max_bid` as `100`. The circuit enforces that the `bid` does not exceed the `max_bid` cap. Since it is not possible to compare `Field` values directly, the circuit casts the bid to `u32` before checking against the cap.

## Objective

The `max_bid` is `100`. Produce a valid proof where your supplied `bid` exceeds the `max_bid`.

## How to verify your answer

1. Generate the input file: `nargo check`. This will create a [`Prover.toml`](./Prover.toml) file.
2. Edit [`Prover.toml`](./Prover.toml) to craft your exploit. Example values can be found in the [`Prover.toml.example`](./Prover.toml.example) file.
3. Run `./verify.sh` to compile, prove, and verify.

The challenge is solved when `verify.sh` prints `SOLVED`.

> [!TIP]
> You can run `./verify.sh` with the [`Prover.toml.example`](./Prover.toml.example) values first to confirm your setup works before crafting the exploit.

## Hint

<details>
<summary>Hint</summary>

What is the result of `bid as u32` when `bid` is a `Field` larger than the maximum value of a `u32`?

</details>
