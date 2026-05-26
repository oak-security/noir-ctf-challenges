// Patched circuit for Challenge 07 -- BoundedVec Residual (Capacity vs Length).
// Fix: read the coupon through BoundedVec::get(), which bounds the index by the
// active `len`, instead of indexing the raw .storage() backing array (bounded only
// by the static capacity N). Every access then stays inside the notarized region
// [0, len), and any read into the attacker-controlled residual [len, N) is rejected.

use sha256::sha256_var;

global N: u32 = 64;
global PD: u32 = 7;

global NOTARIZED_DIGEST: [u8; 32] = [
    233, 245, 162, 119, 129, 249, 56, 112, 134, 209, 6, 91, 176, 226, 68, 154,
    194, 117, 102, 187, 219, 45, 84, 249, 255, 114, 21, 27, 214, 186, 182, 170,
];

fn pts_tag() -> [u8; 5] {
    [59, 80, 84, 83, 58]
}

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
    assert(notarize(coupon) == NOTARIZED_DIGEST, "coupon is not notarized by the issuer");

    let tag = pts_tag();
    for k in 0..tag.len() {
        assert(coupon.get(marker + k) == tag[k], "no ;PTS: tag at marker"); // <- FIXED: .get() bounds the index by len, not capacity N
    }
    let from_index = marker + tag.len();

    for i in 0..PD {
        assert(coupon.get(from_index + i) == bound_points_digits[i], "points binding mismatch");
    }

    assert(parse_points(bound_points_digits) == claimed_points, "claimed_points != coupon points");
}
