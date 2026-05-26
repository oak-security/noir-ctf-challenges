# Challenge 05: Nullifier Malleability (Aztec-themed)

## Background

A **Merkle tree** is a binary tree of hashes. Each leaf is the hash of some data, and each internal node is the hash of its two children. The root is a single hash that summarizes all leaves. To prove a leaf is in the tree without revealing the other leaves, you provide the leaf, its sibling hash, and whether it's the left or right child. This is called a **Merkle inclusion proof**.

A **nullifier** is a unique tag derived from a note. Privacy pools use nullifiers as replay defense: when a user withdraws, they reveal a nullifier and the contract records it. If the same nullifier appears again, the contract rejects the withdrawal as a double-spend. For more on how nullifiers work in practice, see the [Aztec documentation](https://docs.aztec.network/developers/docs/resources/glossary#nullifier).

## Setup

The circuit (`src/main.nr`) takes the following parameters:

| Parameter | Visibility | Description |
|-----------|-----------|-------------|
| `note_secret` | private | The secret that identifies your note |
| `sibling` | private | The sibling hash in the Merkle inclusion proof |
| `is_right` | private | Whether your note is the right child (`true`) or left child (`false`) |
| `spend_tag` | private | A tag included in the nullifier derivation |
| `note_tree_root` | public | The Merkle tree root the contract stores on-chain |
| `nullifier` | public | The nullifier revealed to the contract |

The setup is a privacy pool styled after Aztec's note model with the following features:

- **Deposit**: a user picks a `note_secret` and inserts its commitment `note_commit(note_secret)` as a leaf in a Merkle tree. The contract stores the tree root.
- **Withdraw**: the user proves (in ZK) that they know a `note_secret` whose commitment is a leaf in the tree, by providing a Merkle inclusion proof (sibling hash + position). They also reveal a `nullifier` derived from their note.
- **Replay defense**: the pool records each `nullifier` in a spent-set. If the same `nullifier` is submitted again, the withdrawal is rejected.

## Objective

You own a note with `note_secret = 2` at position 0 (left child). The tree has two leaves:

| Position | Leaf (note commitment) |
|----------|----------------------|
| 0 (left) | `note_commit(2) = 29` (your note) |
| 1 (right) | `99` (another user's deposit) |

The on-chain root is `note_tree_root = hash_pair(29, 99) = 33969`. You already withdrew once with `nullifier = hash_pair(2, 0) = 21`.

Your task is to withdraw the same note **again** by producing a valid proof with the same `note_tree_root` and `note_secret`, but a *different* `nullifier`.

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

The nullifier is `hash_pair(note_secret, spend_tag)`. Is there anything that constrains `spend_tag`?

</details>
