# Challenge 01: Missing Constraint

## Background

In zero-knowledge (ZK) circuits, a **prover** generates a proof that convinces a
**verifier** of some statement without revealing private inputs. The circuit
defines what the prover must satisfy. If the circuit has a bug, the prover can
generate a valid proof for a false statement.

## Setup

The circuit implements a password-gated access system. A smart contract stores the circuit's verification key and uses it to verify proofs. If a proof is valid, the contract grants access.

To gain access, users must prove they know the password by generating a ZK proof that their `secret` parameter satisfies the circuit's constraints and hashes to `expected_hash`.

The contract is deployed with the circuit's verification key and stores `expected_hash = 74844` (computed from the real password). When a user submits a proof, the contract verifies it against this value.

## Objective

Produce a valid proof for `expected_hash = 74844` without supplying the `secret` parameter as `42`. 

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

In Noir, `a == b` is an *expression* that returns `bool`. Is the equality between `computed` and
`expected_hash` actually enforced?

</details>