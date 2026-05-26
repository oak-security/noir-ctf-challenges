// NOTE: In a real deployment, `commit` would be a cryptographic commitment scheme. We use a small polynomial here so the target value is easy to compute by hand.
fn commit(x: Field) -> Field {
    x * x + 7 * x + 3
}

fn main(bid: Field, max_bid: pub u32, commitment: pub Field) {
    let bid_u32 = bid as u32;
    assert(bid_u32 as Field == bid); // <- FIXED: ensures bid actually fits in u32
    assert(bid_u32 <= max_bid);

    let computed = commit(bid);
    assert(computed == commitment);
}
