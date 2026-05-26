#!/usr/bin/env bash
# Verify your solution for Challenge 08.
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

# The denomination gate certifies that the public `amount` fits in 16 bits.
# A genuine denomination is in [0, 65535]; the objective is to get an amount
# OUTSIDE that range certified as in-range.
AMOUNT="$(grep -E '^amount\s*=' Prover.toml | sed 's/[^=]*=\s*//' | tr -d '"[:space:]')"

if [[ -z "${AMOUNT}" ]]; then
    echo "ERROR: Prover.toml must contain 'amount'."
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${AMOUNT}" == "50000" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values (honest 50000, a valid 16-bit denomination). Verifying your setup..."
else
    if (( AMOUNT <= 65535 )); then
        echo "ERROR: to solve, certify an amount OUTSIDE the 16-bit range (>= 65536) as in-range. Got: amount=${AMOUNT}"
        exit 1
    fi
    echo "==> [${NAME}] Objective check passed (certifying amount=${AMOUNT}, which needs more than 16 bits, as a valid 16-bit denomination)"
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
    echo "==> [${NAME}] Now craft your exploit: certify an out-of-range amount as a valid 16-bit denomination."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid."
fi
