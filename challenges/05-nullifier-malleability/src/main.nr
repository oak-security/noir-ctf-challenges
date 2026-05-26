/*
Challenge 05 -- Nullifier Malleability (Aztec-themed)

Protocol: Aztec-style privacy pool (deposit / withdraw)
Prover:   Note owner proving they deposited and deriving a nullifier
Verifier: Pool contract that checks the proof, verifies the Merkle root,
          and records the nullifier in a spent-set
Flow:     Deposit adds note commitment to Merkle tree -> withdraw proves
          inclusion and reveals nullifier -> contract checks nullifier not spent

Parameters:
  note_secret    (private) - the secret that identifies the note
  sibling        (private) - the sibling hash in the Merkle inclusion proof
  is_right       (private) - whether the note is the right child (true) or left (false)
  spend_tag      (private) - a tag included in the nullifier derivation
  note_tree_root (public)  - the Merkle tree root stored on-chain
  nullifier      (public)  - the nullifier revealed to the contract
*/

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
    spend_tag: u32,
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
    assert(nullifier == hash_pair(note_secret, spend_tag as Field));
}
