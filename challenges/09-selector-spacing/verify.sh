#!/usr/bin/env bash
# Verify your solution for Challenge 09.
# Usage: ./verify.sh (run from the challenge directory)
set -euo pipefail

CHALLENGE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${CHALLENGE_DIR}/../.." && pwd)"
NAME="$(basename "${CHALLENGE_DIR}")"

# Check environment
source "${ROOT}/scripts/check-env.sh"
echo "==> [${NAME}] Checking environment..."
check_env
echo ""

# A Prover.toml is required (README step 1: `nargo check`, or copy the example).
if [[ ! -f Prover.toml ]]; then
    echo "ERROR: no Prover.toml in this directory."
    echo "       Start from the example:  cp Prover.toml.example Prover.toml"
    echo "       (or generate a blank one with: nargo check), then re-run ./verify.sh"
    exit 1
fi

# The account exposes two entrypoints: pay (allowed) and set_admin (forbidden by
# the deny-list). The only public input is which entrypoint is invoked.
ENTRY="$(grep -E '^entrypoint\s*=' Prover.toml | sed 's/[^=]*=\s*//' | tr -d '"[:space:]')"

if [[ -z "${ENTRY}" ]]; then
    echo "ERROR: Prover.toml must contain 'entrypoint'."
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${ENTRY}" == "0" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values (invoking the allowed entrypoint, pay). Verifying your setup..."
else
    echo "==> [${NAME}] Invoking entrypoint ${ENTRY} (the circuit enforces 0 <= entrypoint < 2)..."
fi
echo ""

echo "==> [${NAME}] Compiling circuit..."
nargo compile >/dev/null

ARTIFACT="$(ls target/*.json | head -n1)"

echo "==> [${NAME}] Writing verification key..."
bb write_vk -b "${ARTIFACT}" -o ./target >/dev/null

echo "==> [${NAME}] Executing with your Prover.toml..."
nargo execute >/dev/null

WITNESS="$(ls target/*.gz | head -n1)"

echo "==> [${NAME}] Generating proof..."
bb prove -b "${ARTIFACT}" -w "${WITNESS}" -o ./target >/dev/null

echo "==> [${NAME}] Verifying proof..."
bb verify -k ./target/vk -p ./target/proof
rm -rf out   # bb verify leaves an empty ./out directory; remove it

echo ""
if [[ "${IS_EXAMPLE}" == true ]]; then
    echo "==> [${NAME}] Proof verified! Your setup works correctly."
    echo "==> [${NAME}] Now craft your exploit: invoke the forbidden set_admin entrypoint (entrypoint = 1)."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid."
fi
