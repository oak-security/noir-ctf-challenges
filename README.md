# Noir CTF

A set of exercises and introduction to [Noir](https://noir-lang.org) circuit security. Each challenge is a deliberately broken Noir circuit, and your goal is to exploit the bug by producing a valid proof for a statement that *should* be impossible by crafting a malicious `Prover.toml`.

Inspired by the Oak Security [CosmWasm CTF](https://github.com/oak-security/cosmwasm-ctf).

## Prerequisites

This CTF is pinned to a specific toolchain: `nargo` **1.0.0** and `bb` **6.0.0**. All challenges are verified against this pair. Use exactly these versions: `nargo` and `bb` must match each other, and the challenges use compile-time APIs that change between Noir releases.

- `nargo` v1.0.0: install [`noirup`](https://noir-lang.org/docs/getting_started/quick_start#installation), then `noirup --version 1.0.0`.
- `bb` (Barretenberg) v6.0.0: install via noir's own [`install_bb.sh`](https://github.com/noir-lang/noir/blob/v1.0.0/scripts/install_bb.sh).

Run the environment check [script](scripts/check-env.sh) to verify your install:

```sh
bash scripts/check-env.sh
```

If everything is set up correctly, you should see `Installation check passed`.

## Layout

```tree
noir-ctf/
├── challenges/
│   ├── 01-missing-constraint/
│   ├── 02-missing-blinding-factor/
│   ├── 03-field-wraparound/
│   ├── 04-range-check/
│   ├── 05-nullifier-malleability/
│   ├── 06-unconstrained-division/
│   ├── 07-boundedvec-residual/
│   ├── 08-comptime-bit-decomp/
│   ├── 09-selector-spacing/
│   └── 10-noncanonical-encoding/
├── solutions/                       # one folder per challenge (spoilers!)
├── scripts/
│   ├── check-env.sh                 # environment check
│   └── test-all.sh                  # maintainer test: every challenge vs. its solution
├── LICENSE
└── README.md
```

## Playing a challenge

```sh
cd challenges/01-missing-constraint
cat README.md                        # read the scenario & objective
cp Prover.toml.example Prover.toml   # start from the example inputs
# edit Prover.toml to craft your exploit
./verify.sh                          # compile, prove, and verify
```

Each challenge includes a `verify.sh` script that compiles the circuit, generates a proof, and verifies it. If the script prints **`SOLVED`**, you've completed the challenge.

> [!TIP]
> Run `./verify.sh` with the unmodified `Prover.toml.example` values first to confirm your setup works before crafting the exploit.

## Challenges

Roughly ordered easiest → hardest.

| # | Challenge | Topic |
|---|-----------|-------|
| 01 | [Missing Constraint](challenges/01-missing-constraint/) | Under-constrained circuit |
| 02 | [Missing Blinding Factor](challenges/02-missing-blinding-factor/) | Commitment without a hiding salt |
| 03 | [Field Wraparound](challenges/03-field-wraparound/) | Field arithmetic underflow |
| 04 | [Range Check Omission](challenges/04-range-check/) | Truncation on Field-to-integer cast |
| 05 | [Nullifier Malleability](challenges/05-nullifier-malleability/) | Free witness in nullifier derivation |
| 06 | [Unconstrained Division](challenges/06-unconstrained-division/) | Unconstrained function trust |
| 07 | [BoundedVec Residual](challenges/07-boundedvec-residual/) | Capacity-vs-length: un-notarized buffer residual |
| 08 | [Comptime Range Gadget](challenges/08-comptime-bit-decomp/) | Quote/unquote accumulation bug in a generated range check |
| 09 | [Selector Spacing Bypass](challenges/09-selector-spacing/) | Quote token-padding mismatch in compile-time selector strings |
| 10 | [Non-Canonical Encoding](challenges/10-noncanonical-encoding/) | Foreign-field `validate_in_range` vs `validate_in_field` |

## Testing the challenges

For maintainers: [`scripts/test-all.sh`](scripts/test-all.sh) runs every challenge against its solution (example inputs, exploit, and patched circuit) and checks that each patched circuit rejects the exploit at the expected place. CI runs it on pushes to `main` and on PRs with the pinned toolchain, and weekly with the newest Noir release.

```sh
scripts/test-all.sh            # all challenges
scripts/test-all.sh '06-*'     # one challenge
```

## License

[MIT](LICENSE).

## Disclaimer

Challenges are intentionally broken. Do not copy them into production.

## Need an audit?

If you're building with Noir or zero-knowledge circuits and need a security audit, reach out to [Oak Security](https://oaksecurity.io/#schedule).