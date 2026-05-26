/*
Challenge 10 -- Allowlisted Token Claim (foreign-field commitments)

Protocol: Allowlisted token claim with double-claim protection
Prover:   An enrolled user proving knowledge of (s, r) behind an allowlist commitment
Verifier: A registry that reads claim_slot (public) and the emitted nullifier (public output)
Flow:     Enroll id_i = commit(s_i, r_i) -> claim by proving commit(s, r) == id_i; nullifier = H(limbs(s)) blocks double-claims

The commitments live in secp256k1's scalar field (order n), implemented with
noir-bignum (each value is an array of 120-bit limbs). Users enroll by a Pedersen
commitment to a secret scalar `s` and blinding `r`:

    id_i = commit(s_i, r_i) = s_i * A + r_i * B   (mod n)

The published allowlist holds the enrolled commitments. To claim, a user proves
knowledge of (s, r) that opens some allowlist slot, and emits

    nullifier = H(limbs(s))

so the on-chain registry can reject double-claims (one nullifier per identity).
*/

use bignum::Secp256k1_Fr;
use bignum::BigNum;

global ALLOWLIST_SIZE: u32 = 2;

// Public protocol constants for the commitment (fixed, published).
fn commitment_bases() -> (Secp256k1_Fr, Secp256k1_Fr) {
    let a = Secp256k1_Fr::from_limbs([314159265358979323846264338327, 0, 0]);
    let b = Secp256k1_Fr::from_limbs([271828182845904523536028747135, 0, 0]);
    (a, b)
}

// Pedersen commitment over the secp256k1 scalar field.
fn commit(s: Secp256k1_Fr, r: Secp256k1_Fr) -> Secp256k1_Fr {
    let (a, b) = commitment_bases();
    s * a + r * b
}

// The published allowlist: one opaque commitment per enrolled user.
//
// Each slot is a precomputed Pedersen commitment  id_i = commit(s_i, r_i), where
// s_i is the user's SECRET scalar (a high-entropy value only they know, like a
// private key -- NOT an encoding of a name) and r_i is a random blinding factor.
// Enrollment runs commit(...) off-chain; only the resulting commitments are
// published here. The secrets never appear in the circuit. ("User A"/"User B"
// are just labels for the slots.) The same commit() below re-derives the
// commitment from a claimant's (s, r) to check it against a slot.
fn allowlist() -> [Secp256k1_Fr; ALLOWLIST_SIZE] {
    [
        // slot 0 -- User A:  commit(s_A, r_A)
        Secp256k1_Fr::from_limbs([1283760567336345058482799375748290103, 162630401948933460950627, 0]),
        // slot 1 -- User B:  commit(s_B, r_B)
        Secp256k1_Fr::from_limbs([356534552207899287651010307309273375, 256947201139787599477870, 0]),
    ]
}

fn main(s_limbs: [u128; 3], r_limbs: [u128; 3], claim_slot: pub u32) -> pub Field {
    assert(claim_slot < ALLOWLIST_SIZE, "claim_slot out of range");

    let s = Secp256k1_Fr::from_limbs(s_limbs);
    let r = Secp256k1_Fr::from_limbs(r_limbs);

    s.validate_in_range();
    r.validate_in_range();

    assert(commit(s, r) == allowlist()[claim_slot], "commitment not in allowlist slot");

    // Nullifier: a Pedersen hash of the secret scalar's three 120-bit limbs, each
    // cast to a native Field for the hash. The registry records one nullifier per
    // claim, so the same identity claiming twice can be detected and rejected.
    let l = s.get_limbs();
    std::hash::pedersen_hash([l[0] as Field, l[1] as Field, l[2] as Field])
}
