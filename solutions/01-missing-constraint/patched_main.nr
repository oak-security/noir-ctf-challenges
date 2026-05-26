// NOTE: In a real deployment, `password_hash` would be a cryptographic hash. We use a small polynomial here so the target value is easy to compute by hand and the test harness stays self-contained.
fn password_hash(x: Field) -> Field {
    // x^3 + 17x + 42
    x * x * x + x * 17 + 42
}

fn main(secret: Field, expected_hash: pub Field) {
    let computed = password_hash(secret);

    assert(computed == expected_hash); // <- FIXED: assert enforces the constraint
}
