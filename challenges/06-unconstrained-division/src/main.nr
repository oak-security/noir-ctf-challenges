/*
Challenge 06 -- Unconstrained Division

Protocol: Verifiable integer division
Prover:   A user claiming numerator / divisor == claimed_quotient
Verifier: A smart contract that reads (numerator, divisor, claimed_quotient) from public inputs
Flow:     Prover generates proof of correct division -> contract verifies and trusts the quotient
*/

unconstrained fn divmod(numerator: u32, divisor: u32) -> (u32, u32) {
    (numerator / divisor, numerator % divisor)
}

fn main(numerator: pub u32, divisor: pub u32, claimed_quotient: pub u32) {
    // SAFETY: divmod is unconstrained; (q, r) are prover-supplied witnesses that the constraint system needs to re-validate.
    let (q, r) = unsafe { divmod(numerator, divisor) };

    assert(q * divisor + r == numerator);
    assert(q == claimed_quotient);
}
