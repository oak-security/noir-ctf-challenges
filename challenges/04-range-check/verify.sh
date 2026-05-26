#!/usr/bin/env bash
# Verify your solution for Challenge 04.
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
BID="$(parse_toml bid)"
MAX_BID="$(parse_toml max_bid)"
COMMITMENT="$(parse_toml commitment)"

if [[ -z "${BID}" || -z "${MAX_BID}" || -z "${COMMITMENT}" ]]; then
    echo "ERROR: Prover.toml must contain 'bid', 'max_bid', and 'commitment'."
    exit 1
fi
if [[ "${MAX_BID}" != "100" ]]; then
    echo "ERROR: max_bid must be 100. Got: ${MAX_BID}"
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${BID}" == "50" && "${COMMITMENT}" == "2853" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values. Running proof to verify your setup..."
else
    if [[ "${BID}" -le 100 ]]; then
        echo "ERROR: bid must exceed max_bid (100). Got: ${BID}"
        exit 1
    fi
    echo "==> [${NAME}] Objective check passed (bid > 100)"
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
    echo "==> [${NAME}] Now craft your exploit: place a bid that exceeds max_bid."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid with a bid exceeding the cap."
fi
