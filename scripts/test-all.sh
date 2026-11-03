#!/usr/bin/env bash
# Test every challenge against its solution, in three phases:
#   example  verify.sh accepts Prover.toml.example ("Proof verified")
#   exploit  verify.sh accepts the solution's exploit ("SOLVED")
#   patched  the patched circuit rejects the exploit at the expected place
#
# Usage: scripts/test-all.sh [challenge-glob]   e.g. scripts/test-all.sh '0[1-3]-*'
#
# Solution files used, per solutions/<challenge>/:
#   Prover.toml              exploit inputs
#   exploit_main.nr          (optional) exploit circuit, if the exploit edits source
#   patched_main.nr          fixed circuit
#   patched_exploit_main.nr  (optional) fixed circuit with the exploit's source edits
#   Prover.patched.toml      (optional) inputs for the patched phase
#
# Runs in a temporary copy of the repo, so the working tree is not changed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GLOB="${1:-*}"

# Where each patched circuit must reject the exploit: a fixed string that must
# appear in the `nargo execute` output (the failing source line, or the
# assertion message).
expected_failure() {
    case "$1" in
        01-*) echo "assert(computed == expected_hash);" ;;
        02-*) echo "assert(h2(move, salt) == commitment);" ;;
        03-*) echo "let computed = old_balance_u64 - amount_u64;" ;;
        04-*) echo "assert(bid_u32 as Field == bid);" ;;
        05-*) echo "assert(nullifier == note_commit(note_secret));" ;;
        06-*) echo "assert(r < divisor);" ;;
        07-*) echo "Attempted to read past end of BoundedVec" ;;
        08-*) echo "bit is not boolean" ;;
        09-*) echo "entrypoint is forbidden" ;;
        10-*) echo "validate_in_field" ;;
        *) return 1 ;;
    esac
}

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -r "${ROOT}/challenges" "${ROOT}/scripts" "${ROOT}/solutions" "${WORK}/"

source "${ROOT}/scripts/check-env.sh"
check_env
echo ""

pass=0
fail=0

report() { # report <name> <phase> <ok> <log>
    if [[ "$3" == true ]]; then
        echo "  PASS  $1 $2"
        pass=$((pass + 1))
    else
        echo "  FAIL  $1 $2"
        sed 's/^/        | /' "$4" | tail -n 25
        fail=$((fail + 1))
    fi
}

for dir in "${WORK}"/challenges/${GLOB}/; do
    name="$(basename "${dir}")"
    sol="${WORK}/solutions/${name}"
    log="${WORK}/${name}"
    ok=false

    # example
    cp "${dir}/Prover.toml.example" "${dir}/Prover.toml"
    (cd "${dir}" && rm -rf target && ./verify.sh) >"${log}.example.log" 2>&1 \
        && grep -q "Proof verified" "${log}.example.log" && ok=true
    report "${name}" example "${ok}" "${log}.example.log"

    # exploit
    ok=false
    cp "${sol}/Prover.toml" "${dir}/Prover.toml"
    [[ -f "${sol}/exploit_main.nr" ]] && cp "${sol}/exploit_main.nr" "${dir}/src/main.nr"
    (cd "${dir}" && rm -rf target && ./verify.sh) >"${log}.exploit.log" 2>&1 \
        && grep -q "SOLVED" "${log}.exploit.log" && ok=true
    report "${name}" exploit "${ok}" "${log}.exploit.log"

    # patched
    ok=false
    if [[ -f "${sol}/patched_exploit_main.nr" ]]; then
        cp "${sol}/patched_exploit_main.nr" "${dir}/src/main.nr"
    else
        cp "${sol}/patched_main.nr" "${dir}/src/main.nr"
    fi
    [[ -f "${sol}/Prover.patched.toml" ]] && cp "${sol}/Prover.patched.toml" "${dir}/Prover.toml"
    if expected="$(expected_failure "${name}")"; then
        if (cd "${dir}" && rm -rf target && nargo execute) >"${log}.patched.log" 2>&1; then
            echo "patched circuit accepted the exploit" >>"${log}.patched.log"
        elif grep -qF -- "${expected}" "${log}.patched.log"; then
            ok=true
        else
            echo "expected the failure to mention: ${expected}" >>"${log}.patched.log"
        fi
    else
        echo "no expected failure set for ${name} in $(basename "$0")" >"${log}.patched.log"
    fi
    report "${name}" patched "${ok}" "${log}.patched.log"
done

echo ""
echo "${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
