#!/usr/bin/env bash
# Verify your solution for Challenge 01.
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
SECRET="$(parse_toml secret)"
EXPECTED_HASH="$(parse_toml expected_hash)"

if [[ -z "${SECRET}" || -z "${EXPECTED_HASH}" ]]; then
    echo "ERROR: Prover.toml must contain both 'secret' and 'expected_hash'."
    exit 1
fi
if [[ "${EXPECTED_HASH}" != "74844" ]]; then
    echo "ERROR: expected_hash must be 74844. Got: ${EXPECTED_HASH}"
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${SECRET}" == "42" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values. Running proof to verify your setup..."
else
    echo "==> [${NAME}] Objective check passed (secret != 42)"
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
    echo "==> [${NAME}] Now craft your exploit: produce a valid proof without knowing the real password (secret = 42)."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid with a different secret."
fi
