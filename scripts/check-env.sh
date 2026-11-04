#!/usr/bin/env bash
# Environment check for the Noir CTF.
# Verifies that nargo and bb are installed at the pinned, known-good versions.
# Sourced by each challenge's verify.sh before running.
# Set NOIR_CTF_ALLOW_OTHER_VERSIONS=1 to only warn on a version mismatch
# (CI uses this to test against the newest nargo and bb).
set -euo pipefail

# Pinned toolchain -- the only versions all challenges are verified against.
# nargo and bb must match this pair, or compilation / proving will crash.
REQUIRED_NARGO="1.0.0"
REQUIRED_BB="6.0.0"

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
            if [[ -n "${NOIR_CTF_ALLOW_OTHER_VERSIONS:-}" ]]; then
                echo "WARNING: nargo ${REQUIRED_NARGO} is pinned (found ${nargo_ver})."
            else
                echo "ERROR: nargo ${REQUIRED_NARGO} is required (found ${nargo_ver})."
                echo "       Install it with: noirup --version ${REQUIRED_NARGO}"
                errors=$((errors + 1))
            fi
        fi
    fi

    # --- bb (barretenberg) ---
    if ! command -v bb &>/dev/null; then
        echo "ERROR: bb (barretenberg) is not installed. Install v${REQUIRED_BB}:"
        echo "       curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/next/barretenberg/bbup/install | bash"
        echo "       bbup -v ${REQUIRED_BB}"
        errors=$((errors + 1))
    else
        local bb_ver
        bb_ver="$(bb --version 2>&1 | head -n1 | sed 's/^v//')"
        echo "  bb:    ${bb_ver}"
        if [[ "${bb_ver}" != "${REQUIRED_BB}" ]]; then
            if [[ -n "${NOIR_CTF_ALLOW_OTHER_VERSIONS:-}" ]]; then
                echo "WARNING: bb ${REQUIRED_BB} is pinned (found ${bb_ver})."
            else
                echo "ERROR: bb ${REQUIRED_BB} is required (found ${bb_ver})."
                echo "       Install it with: bbup -v ${REQUIRED_BB}"
                errors=$((errors + 1))
            fi
        fi
    fi

    if [[ ${errors} -gt 0 ]]; then
        echo ""
        echo "Fix the above before proceeding."
        echo "This CTF is verified only on nargo ${REQUIRED_NARGO} + bb ${REQUIRED_BB}."
        exit 1
    fi

    echo "Installation check passed (pinned: nargo ${REQUIRED_NARGO} + bb ${REQUIRED_BB})."
}

# Run directly if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_env
fi
