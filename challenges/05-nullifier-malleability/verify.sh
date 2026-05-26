#!/usr/bin/env bash
# Verify your solution for Challenge 05.
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
NOTE_SECRET="$(parse_toml note_secret)"
TREE_ROOT="$(parse_toml note_tree_root)"
NULLIFIER="$(parse_toml nullifier)"

if [[ -z "${NOTE_SECRET}" || -z "${TREE_ROOT}" || -z "${NULLIFIER}" ]]; then
    echo "ERROR: Prover.toml must contain 'note_secret', 'note_tree_root', and 'nullifier'."
    exit 1
fi
if [[ "${NOTE_SECRET}" != "2" ]]; then
    echo "ERROR: note_secret must be 2. Got: ${NOTE_SECRET}"
    exit 1
fi
if [[ "${TREE_ROOT}" != "33969" ]]; then
    echo "ERROR: note_tree_root must be 33969. Got: ${TREE_ROOT}"
    exit 1
fi

# Detect example vs exploit
IS_EXAMPLE=false
if [[ "${NULLIFIER}" == "21" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values. Running proof to verify your setup..."
else
    echo "==> [${NAME}] Objective check passed (nullifier != 21)"
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
    echo "==> [${NAME}] Now craft your exploit: produce a different nullifier for the same note."
else
    echo "==> [${NAME}] SOLVED! Your proof is valid with a different nullifier."
fi
