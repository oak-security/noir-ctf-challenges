/*
Challenge 01 -- Missing Constraint

Protocol: Password-gated access
Prover:   A user claiming to know the password
Verifier: A smart contract holding `expected_hash = password_hash(real_password)`
Flow:     Prover generates proof -> Contract verifies proof -> grants access
*/


// NOTE: In a real deployment, `password_hash` would be a cryptographic hash. We use a small polynomial here so the target value is easy to compute by hand and the test harness stays self-contained.
fn password_hash(x: Field) -> Field {
    // x^3 + 17x + 42
    x * x * x + x * 17 + 42
}

fn main(secret: Field, expected_hash: pub Field) {
    let computed = password_hash(secret);

    let _check = computed == expected_hash;
}
