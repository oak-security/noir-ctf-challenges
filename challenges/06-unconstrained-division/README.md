# Challenge 06: Unconstrained Division

## Setup

The circuit implements verifiable integer division. A smart contract stores the circuit's verification key and uses it to verify that a prover correctly computed `numerator / divisor`.

The circuit accepts public inputs `numerator`, `divisor`, and `claimed_quotient`. The author offloaded the actual division to an `unconstrained fn` (as witness generation is cheap) and added a constraint to check the result.

For example, when a user provides a proof with `numerator = 10, divisor = 3, claimed_quotient = 3`, the contract verifies it and trusts that the division is correct.

## Objective

Produce a valid proof for `numerator = 10`, `divisor = 3`, `claimed_quotient = 0`. The honest answer is `3`. You must convince the verifier that `10 / 3 == 0`.

## How to verify your answer

1. Generate the input file: `nargo check`. This will create a [`Prover.toml`](./Prover.toml) file.
2. Edit [`Prover.toml`](./Prover.toml) to craft your exploit. Example values can be found in the [`Prover.toml.example`](./Prover.toml.example) file.
3. Run `./verify.sh` to compile, prove, and verify.

The challenge is solved when `verify.sh` prints `SOLVED`.

> [!TIP]
> You can run `./verify.sh` with the [`Prover.toml.example`](./Prover.toml.example) values first to confirm your setup works before crafting the exploit.

## Hints

<details>
<summary>Hint 1</summary>

For this challenge, you need to modify the `unconstrained` function to return incorrect values.

</details>


<details>
<summary>Hint 2</summary>

Look into the division theorem (also known as Euclidean division). What constraint is missing that would pin down `(q, r)` uniquely?

</details>