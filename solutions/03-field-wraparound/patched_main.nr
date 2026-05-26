fn main(old_balance: Field, amount: pub Field, new_balance: pub Field) {
    let old_balance_u64 = old_balance as u64;
    let amount_u64 = amount as u64;
    let computed = old_balance_u64 - amount_u64; // <- FIXED: underflow panics in u64
    assert(computed as Field == new_balance);
}
