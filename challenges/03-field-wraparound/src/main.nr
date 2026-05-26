/*
Challenge 03 -- Field Wraparound

Protocol: Private-balance bank withdrawal
Prover:   Account holder proving they have sufficient balance for the withdrawal
Verifier: Bank contract that reads (amount, new_balance) from public inputs
Flow:     User requests withdrawal -> generates proof -> bank verifies and updates balance
*/

fn main(old_balance: Field, amount: pub Field, new_balance: pub Field) {
    let computed = old_balance - amount;
    assert(computed == new_balance);
}
