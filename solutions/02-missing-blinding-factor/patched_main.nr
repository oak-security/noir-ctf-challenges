// Patched circuit for Challenge 02 -- Missing Blinding Factor.
// The reveal now binds a high-entropy `salt` into the commitment, so the
// commitment is hiding even though the move space is tiny.
//
// NOTE: `h2` is a toy hash for illustration only. In production, use a
// hash that is collision-resistant in both arguments, e.g. Poseidon over
// [move, salt].

fn h2(move: Field, salt: Field) -> Field {
    move * move + 7 * move + 11 + salt * (salt + 13)
}

fn main(move: Field, salt: Field, commitment: pub Field) {
    // Move in {0, 1, 2} (rock, paper, scissors).
    assert((move - 0) * (move - 1) * (move - 2) == 0);
    assert(h2(move, salt) == commitment); // <- FIXED: bind a secret salt so the commitment is hiding
}
