#!/usr/bin/env bash
# Verify your solution for Challenge 07.
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

# The issuer's notarized digest is fixed in the circuit (global NOTARIZED_DIGEST),
# so the only public input to check here is claimed_points. The circuit itself
# enforces that the coupon hashes (over its `len` bytes) to that fixed digest.
CLAIMED="$(grep -E '^claimed_points\s*=' Prover.toml | sed 's/[^=]*=\s*//' | tr -d '"[:space:]')"

if [[ -z "${CLAIMED}" ]]; then
    echo "ERROR: Prover.toml must contain 'claimed_points'."
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${CLAIMED}" == "10" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values (honest 10-point redemption). Verifying your setup..."
else
    if [[ "${CLAIMED}" != "1000000" ]]; then
        echo "ERROR: to solve, redeem 1000000 points against the issuer's notarized coupon. Got: claimed_points=${CLAIMED}"
        exit 1
    fi
    echo "==> [${NAME}] Objective check passed (claiming 1000000 points against the fixed 10-point coupon)"
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
    echo "==> [${NAME}] Now craft your exploit: redeem 1000000 points against the issuer's fixed notarized coupon."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid."
fi
