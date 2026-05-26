/*
Challenge 02 -- Missing Blinding Factor

Protocol: Commit-reveal rock-paper-scissors
Prover:   A player revealing that their commitment opens to a specific move
Verifier: A smart contract that reads `commitment` from public inputs
Flow:     Commit phase publishes a commitment to a move -> reveal proof opens it to a move
*/

fn h(x: Field) -> Field {
    x * x + 7 * x + 11
}

fn main(move: Field, commitment: pub Field) {
    // Move in {0, 1, 2} (rock, paper, scissors).
    assert((move - 0) * (move - 1) * (move - 2) == 0);
    // Open the commitment.
    assert(h(move) == commitment);
}
