# Challenge 03: Field Wraparound

## Setup

The circuit implements a private withdrawal. A user holds an account with a private `old_balance`, withdraws a public `amount`, and publishes a new public `new_balance`. The bank contract reads `new_balance` from the proof's public inputs and updates its records.

Your real `old_balance` is `10`. The bank does not know your balance. It only knows what the circuit attests to.

## Objective

Withdraw `amount = 1000` while convincing the verifier that your `old_balance` is `10`. The proof should verify, letting the bank accept the resulting `new_balance` as your new account state.

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

`Field` is a value modulo the BN254 scalar prime `p = 21888242871839275222246405745257275088548364400416034343698204186575808495617`. What does `10 - 1000` produce in modular arithmetic?

</details>