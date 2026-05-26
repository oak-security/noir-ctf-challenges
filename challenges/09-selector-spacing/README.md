# Challenge 09: Selector Spacing Bypass

## Setup

An Aztec-style account gates calls by **function selector** — the canonical
signature `name(argType,...)` of an entrypoint, built at compile time from the
function's tokens (its name and parameter types) and assembled into a string
with `as_quoted_str`. The account keeps a **deny-list** of forbidden signatures;
the generated guard admits an entrypoint iff its selector is not on the list.

Two entrypoints, both taking `(Field, Field)`:

| `entrypoint` | function | status |
|---|---|--------|
| 0 | `pay(recipient, amount)` | allowed |
| 1 | `set_admin(new_admin, key)` | **FORBIDDEN** |

The only public input is `entrypoint` — which one is invoked. Calling
`set_admin` is supposed to be impossible.

## Objective

Produce a valid proof that invokes the forbidden `set_admin` entrypoint — i.e.
`entrypoint = 1`.

## How to verify your answer

1. `nargo check` — creates a [`Prover.toml`](./Prover.toml). The honest example (`entrypoint = 0`) is in [`Prover.toml.example`](./Prover.toml.example).
2. Edit [`Prover.toml`](./Prover.toml) to craft your exploit.
3. `./verify.sh` — compiles, proves, and verifies. It prints `SOLVED` when you succeed.

## Hints

<details>
<summary>Hint 1</summary>

The deny-list blocks an entrypoint only if its selector **string-matches** the
forbidden entry. But the two are built differently — the selector from the
function's tokens in `entrypoint_signature`, the forbidden entry as a written
string in `generate_guard`. Compare the exact characters they produce.

</details>

<details>
<summary>Hint 2</summary>

A `Quoted` is a token stream, and turning one into a string is not the same as
typing that string by hand — pay attention to the spacing *between tokens*. Try
adding a `println` inside `entrypoint_signature` (or `generate_guard`) to dump
what the selector for `set_admin` actually looks like, and hold it next to the
deny-list literal `"set_admin(Field,Field)"` character for character.

</details>
