#!/usr/bin/env bash
# Verify your solution for Challenge 03.
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

# Parse a value from Prover.toml: parse_toml <key>
parse_toml() {
    grep -E "^$1\s*=" Prover.toml | sed 's/[^=]*=\s*//' | tr -d '"[:space:]'
}

# Input validation
OLD_BAL="$(parse_toml old_balance)"
AMOUNT="$(parse_toml amount)"
NEW_BAL="$(parse_toml new_balance)"

if [[ -z "${OLD_BAL}" || -z "${AMOUNT}" || -z "${NEW_BAL}" ]]; then
    echo "ERROR: Prover.toml must contain 'old_balance', 'amount', and 'new_balance'."
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${OLD_BAL}" == "1000" && "${AMOUNT}" == "10" && "${NEW_BAL}" == "990" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values. Running proof to verify your setup..."
else
    if [[ "${OLD_BAL}" != "10" ]]; then
        echo "ERROR: old_balance must be 10. Got: ${OLD_BAL}"
        exit 1
    fi
    if [[ "${AMOUNT}" != "1000" ]]; then
        echo "ERROR: amount must be 1000. Got: ${AMOUNT}"
        exit 1
    fi
    echo "==> [${NAME}] Objective check passed"
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
    echo "==> [${NAME}] Now craft your exploit: withdraw 1000 from a balance of 10."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid."
fi
