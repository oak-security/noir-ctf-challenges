// NOTE: In a real deployment, these would be cryptographic hashes (e.g. Poseidon). We use small polynomials here so target values are easy to compute by hand.
fn note_commit(x: Field) -> Field {
    x * x + 7 * x + 11
}

fn hash_pair(a: Field, b: Field) -> Field {
    2 * a * a + 3 * b * b + a * b + 13
}

fn main(
    note_secret: Field,
    sibling: Field,
    is_right: bool,
    note_tree_root: pub Field,
    nullifier: pub Field,
) {
    let note_commitment = note_commit(note_secret);

    let root = if is_right {
        hash_pair(sibling, note_commitment)
    } else {
        hash_pair(note_commitment, sibling)
    };

    assert(root == note_tree_root);
    assert(nullifier == note_commit(note_secret));
}
