// Patched circuit for Challenge 10 -- Non-Canonical Foreign-Field Encoding.
// Fix: call validate_in_field() (enforces value < n) on every foreign-field
// witness, so a non-canonical encoding such as s_A + n (>= n) is rejected.

use bignum::Secp256k1_Fr;
use bignum::BigNum;

global ALLOWLIST_SIZE: u32 = 2;

fn commitment_bases() -> (Secp256k1_Fr, Secp256k1_Fr) {
    let a = Secp256k1_Fr::from_limbs([314159265358979323846264338327, 0, 0]);
    let b = Secp256k1_Fr::from_limbs([271828182845904523536028747135, 0, 0]);
    (a, b)
}

fn commit(s: Secp256k1_Fr, r: Secp256k1_Fr) -> Secp256k1_Fr {
    let (a, b) = commitment_bases();
    s * a + r * b
}

// Published commitments id_i = commit(s_i, r_i), precomputed off-chain at
// enrollment. Only the opaque commitments are stored; the secrets never appear.
fn allowlist() -> [Secp256k1_Fr; ALLOWLIST_SIZE] {
    [
        Secp256k1_Fr::from_limbs([1283760567336345058482799375748290103, 162630401948933460950627, 0]),
        Secp256k1_Fr::from_limbs([356534552207899287651010307309273375, 256947201139787599477870, 0]),
    ]
}

fn main(s_limbs: [u128; 3], r_limbs: [u128; 3], claim_slot: pub u32) -> pub Field {
    assert(claim_slot < ALLOWLIST_SIZE, "claim_slot out of range");

    let s = Secp256k1_Fr::from_limbs(s_limbs);
    let r = Secp256k1_Fr::from_limbs(r_limbs);

    s.validate_in_range();
    r.validate_in_range();

    s.validate_in_field(); // <- FIXED: enforce canonical field elements (value < n), rejecting s_A + n
    r.validate_in_field();

    assert(commit(s, r) == allowlist()[claim_slot], "commitment not in allowlist slot");

    // Nullifier: a Pedersen hash of the secret scalar's three 120-bit limbs, each
    // cast to a native Field for the hash. The registry records one nullifier per
    // claim, so the same identity claiming twice can be detected and rejected.
    let l = s.get_limbs();
    std::hash::pedersen_hash([l[0] as Field, l[1] as Field, l[2] as Field])
}
