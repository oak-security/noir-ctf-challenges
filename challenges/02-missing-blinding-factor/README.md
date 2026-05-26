# Challenge 02: Missing Blinding Factor

## Setup

A commit-reveal rock-paper-scissors protocol built on Noir proofs.

- **Commit phase.** Each player picks a move ∈ `{0, 1, 2}` (rock, paper, scissors) and publishes a commitment that is meant to hide the move until the reveal phase.
- **Reveal phase.** Each player runs this circuit to prove their published commitment opens to a specific move.

The commitment is computed as `h(move)`, where `h` is the circuit's hash function. Your opponent has committed to a move and published the commitment `29`.

## Objective

Your opponent published `commitment = 29`. Produce a valid reveal proof that opens it, recovering the move it hides, even though you never committed it and never learned their move.

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

How many distinct values can `move` take? What does that imply about how many distinct commitments can ever exist?

</details>


<details>
<summary>Hint 2</summary>

The commitment is a function of `move` alone — there is no secret salt mixed in. What can you do when the set of possible commitments is small enough to write down?

</details>
