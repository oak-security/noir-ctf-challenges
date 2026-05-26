#!/usr/bin/env bash
# Verify your solution for Challenge 06.
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
NUMERATOR="$(parse_toml numerator)"
DIVISOR="$(parse_toml divisor)"
CLAIMED_Q="$(parse_toml claimed_quotient)"

if [[ -z "${NUMERATOR}" || -z "${DIVISOR}" || -z "${CLAIMED_Q}" ]]; then
    echo "ERROR: Prover.toml must contain 'numerator', 'divisor', and 'claimed_quotient'."
    exit 1
fi
if [[ "${NUMERATOR}" != "10" || "${DIVISOR}" != "3" ]]; then
    echo "ERROR: numerator must be 10 and divisor must be 3. Got: numerator=${NUMERATOR}, divisor=${DIVISOR}"
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${CLAIMED_Q}" == "3" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values. Running proof to verify your setup..."
else
    if [[ "${CLAIMED_Q}" != "0" ]]; then
        echo "ERROR: claimed_quotient must be 0 (the false claim). Got: ${CLAIMED_Q}"
        exit 1
    fi
    echo "==> [${NAME}] Objective check passed (claimed_quotient = 0)"
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
    echo "==> [${NAME}] Now craft your exploit: convince the verifier that 10 / 3 == 0."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid."
fi
