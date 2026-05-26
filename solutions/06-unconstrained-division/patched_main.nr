unconstrained fn divmod(numerator: u32, divisor: u32) -> (u32, u32) {
    (numerator / divisor, numerator % divisor)
}

fn main(numerator: pub u32, divisor: pub u32, claimed_quotient: pub u32) {
    // SAFETY: divmod is unconstrained; (q, r) are prover-supplied witnesses that the constraint system needs to re-validate.
    let (q, r) = unsafe { divmod(numerator, divisor) };

    assert(q * divisor + r == numerator);
    assert(r < divisor); // <- FIXED: pins (q, r) to the unique non-negative solution
    assert(q == claimed_quotient);
}
