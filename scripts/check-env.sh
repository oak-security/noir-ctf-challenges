#!/usr/bin/env bash
# Environment check for the Noir CTF.
# Verifies that nargo and bb are installed at the pinned, known-good versions.
# Sourced by each challenge's verify.sh before running.
set -euo pipefail

# Pinned toolchain -- the only versions all challenges are verified against.
# nargo and bb must match this pair, or compilation / proving will crash.
REQUIRED_NARGO="1.0.0-beta.22"
REQUIRED_BB="5.0.0-nightly.20260522"

check_env() {
    local errors=0

    # --- nargo ---
    if ! command -v nargo &>/dev/null; then
        echo "ERROR: nargo is not installed. Install v${REQUIRED_NARGO}:"
        echo "       curl -L https://raw.githubusercontent.com/noir-lang/noirup/refs/heads/main/install | bash"
        echo "       noirup --version ${REQUIRED_NARGO}"
        errors=$((errors + 1))
    else
        local nargo_ver
        nargo_ver="$(nargo --version 2>&1 | head -n1 | awk '{print $4}')"
        echo "  nargo: ${nargo_ver}"
        if [[ "${nargo_ver}" != "${REQUIRED_NARGO}" ]]; then
            echo "ERROR: nargo ${REQUIRED_NARGO} is required (found ${nargo_ver})."
            echo "       Install it with: noirup --version ${REQUIRED_NARGO}"
            errors=$((errors + 1))
        fi
    fi

    # --- bb (barretenberg) ---
    if ! command -v bb &>/dev/null; then
        echo "ERROR: bb (barretenberg) is not installed. Install v${REQUIRED_BB}:"
        echo "       curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/master/barretenberg/bbup/install | bash"
        echo "       bbup -v ${REQUIRED_BB}"
        errors=$((errors + 1))
    else
        local bb_ver
        bb_ver="$(bb --version 2>&1 | head -n1 | sed 's/^v//')"
        echo "  bb:    ${bb_ver}"
        if [[ "${bb_ver}" != "${REQUIRED_BB}" ]]; then
            echo "ERROR: bb ${REQUIRED_BB} is required (found ${bb_ver})."
            echo "       Install it with: bbup -v ${REQUIRED_BB}"
            errors=$((errors + 1))
        fi
    fi

    if [[ ${errors} -gt 0 ]]; then
        echo ""
        echo "Fix the above before proceeding."
        echo "This CTF is verified only on nargo ${REQUIRED_NARGO} + bb ${REQUIRED_BB}; other versions may crash."
        exit 1
    fi

    echo "Installation check passed (nargo ${REQUIRED_NARGO} + bb ${REQUIRED_BB})."
}

# Run directly if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_env
fi
