#!/usr/bin/env bash
# Verify your solution for Challenge 02.
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
MOVE="$(parse_toml move)"
COMMITMENT="$(parse_toml commitment)"

if [[ -z "${MOVE}" || -z "${COMMITMENT}" ]]; then
    echo "ERROR: Prover.toml must contain 'move' and 'commitment'."
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${MOVE}" == "1" && "${COMMITMENT}" == "19" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values. Running proof to verify your setup..."
else
    if [[ "${COMMITMENT}" != "29" || "${MOVE}" != "2" ]]; then
        echo "ERROR: to solve, open the opponent's commitment: set commitment = 29 and move = 2. Got: move=${MOVE}, commitment=${COMMITMENT}"
        exit 1
    fi
    echo "==> [${NAME}] Objective check passed (opening commitment = 29 to move = 2)"
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
    echo "==> [${NAME}] Now craft your exploit: open the opponent's commitment (29) without having committed it."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid."
fi
