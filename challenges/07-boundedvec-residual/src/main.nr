/*
Challenge 07 -- BoundedVec Residual (Capacity vs Length)

Protocol: Zero-knowledge loyalty-coupon redemption
Prover:   A user proving their coupon matches the issuer's notarized commitment
Verifier: A contract that reads claimed_points from public inputs (the notarized digest is fixed in the circuit)
Flow:     The issuer notarizes a coupon (commitment over its active bytes) -> user proves a redemption

The coupon is a Noir `BoundedVec<u8, N>`: a fixed `[u8; N]` backing `storage` paired
with a `len`. Only the first `len` bytes are active content, and the commitment folds
only those. A circuit-input BoundedVec is deserialized straight from the witness --
`storage` and `len` are both prover-supplied, with no constructor run -- so the
residual `storage[len..N)` is attacker-controlled.

The issuer has notarized exactly one coupon: "USER:guest001;PTS:0000010" (10 points, len = 25).
*/

use sha256::sha256_var;

global N: u32 = 64;
global PD: u32 = 7;

// The issuer's published commitment over its single notarized coupon
// "USER:guest001;PTS:0000010" (10 points) -- the fixed, trusted SHA-256 the
// issuer published, baked into the circuit (not a prover-supplied input).
global NOTARIZED_DIGEST: [u8; 32] = [
    233, 245, 162, 119, 129, 249, 56, 112, 134, 209, 6, 91, 176, 226, 68, 154,
    194, 117, 102, 187, 219, 45, 84, 249, 255, 114, 21, 27, 214, 186, 182, 170,
];

// ";PTS:"
fn pts_tag() -> [u8; 5] {
    [59, 80, 84, 83, 58]
}

// The issuer's commitment: SHA-256 over ONLY the coupon's active `len` bytes.
fn notarize(coupon: BoundedVec<u8, N>) -> [u8; 32] {
    sha256_var(coupon.storage(), coupon.len())
}

fn parse_points(d: [u8; PD]) -> u32 {
    let mut acc: u32 = 0;
    for i in 0..PD {
        assert((d[i] >= 48) & (d[i] <= 57), "points field must be ascii digits");
        acc = acc * 10 + (d[i] as u32 - 48);
    }
    acc
}

fn main(
    coupon: BoundedVec<u8, N>,
    marker: u32,
    bound_points_digits: [u8; PD],
    claimed_points: pub u32,
) {
    // (1) the coupon must be the one the issuer notarized (commitment over its active bytes)
    assert(notarize(coupon) == NOTARIZED_DIGEST, "coupon is not notarized by the issuer");

    // (2) locate the ";PTS:" tag in the coupon's backing storage
    let storage = coupon.storage();
    let tag = pts_tag();
    for k in 0..tag.len() {
        assert(storage[marker + k] == tag[k], "no ;PTS: tag at marker");
    }
    let from_index = marker + tag.len();

    // (3) bind the points digits that follow the tag
    for i in 0..PD {
        assert(storage[from_index + i] == bound_points_digits[i], "points binding mismatch");
    }

    // (4) the public claim must equal the coupon's points
    assert(parse_points(bound_points_digits) == claimed_points, "claimed_points != coupon points");
}
