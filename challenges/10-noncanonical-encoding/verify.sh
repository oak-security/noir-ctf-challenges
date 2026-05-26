#!/usr/bin/env bash
# Verify your solution for Challenge 10.
# Usage: ./verify.sh (run from the challenge directory)
set -euo pipefail

CHALLENGE_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${CHALLENGE_DIR}/../.." && pwd)"
NAME="$(basename "${CHALLENGE_DIR}")"

# User A's canonical secret (first limb) -- the honest example claim. Any OTHER
# secret that still opens slot 0 can only be a non-canonical encoding, so success
# is recognised when the proof verifies below, not by hardcoding the exploit value.
CANON_S0="112233445566778899001122334455"

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

CLAIM_SLOT="$(grep -E '^claim_slot\s*=' Prover.toml | sed 's/[^=]*=\s*//' | tr -d '"[:space:]')"
# First element of the s_limbs array.
S0="$(grep -E '^s_limbs\s*=' Prover.toml | grep -oE '"[0-9]+"' | head -n1 | tr -d '"')"

if [[ -z "${CLAIM_SLOT}" || -z "${S0}" ]]; then
    echo "ERROR: Prover.toml must contain 'claim_slot' and 's_limbs'."
    exit 1
fi

# The target is User A's enrolled slot.
if [[ "${CLAIM_SLOT}" != "0" ]]; then
    echo "ERROR: claim_slot must be 0 (User A's slot). Got: ${CLAIM_SLOT}"
    exit 1
fi

# The example uses User A's canonical secret; any other secret that still opens
# slot 0 is a non-canonical encoding (the exploit). The exploit value is NOT
# hardcoded here -- a non-canonical claim is recognised when its proof verifies.
IS_EXAMPLE=false
if [[ "${S0}" == "${CANON_S0}" ]]; then
    IS_EXAMPLE=true
    echo "==> [${NAME}] Detected example values (User A's canonical claim). Verifying your setup..."
else
    echo "==> [${NAME}] Non-canonical secret for slot 0 -- proving the double-claim..."
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
    echo "==> [${NAME}] Now craft your exploit: claim slot 0 a second time so the registry sees a different nullifier (see the README hints)."
else
    echo "==> [${NAME}] SOLVED! A non-canonical encoding produced a second valid claim for slot 0."
fi
