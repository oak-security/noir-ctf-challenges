/*
Challenge 08 -- Comptime Range Gadget

Protocol: Confidential-payment denomination gate
Prover:   A user attesting that a note's `amount` is a valid 16-bit denomination
Verifier: A gate that reads `amount` from public inputs and accepts the note only
          if this proof certifies the amount fits in 16 bits (0 <= amount < 2^16)
Flow:     `amount` is decomposed into 16 witness bits; the gate trusts the proof's
          range attestation and then processes the note.

The 16-bit range check is not written by hand. It is GENERATED at compile time
by the `#[range_gadget]` attribute, which walks the note's bit array and builds,
with `quote`, the two halves of a bit-decomposition range proof: the
little-endian recomposition of `amount`, and a booleanity constraint forcing
every bit to be 0 or 1. A genuine 16-bit denomination decomposes cleanly, so the
gate is meant to accept only amounts in [0, 65535].
*/

// A confidential note: a public `amount` and its 16-bit witness decomposition.
#[range_gadget]
struct Note {
    amount: Field,
    bits: [Field; 16],
}

// Compile-time range-check generator. Walking the 16 bits, it builds the
// little-endian recomposition of `self.amount` and a per-bit booleanity
// constraint, then emits an `assert_in_range` that enforces both.
comptime fn range_gadget(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    let mut recompose = quote { 0 };
    let mut booleanity = quote {};
    let mut weight: Field = 1;
    for i in 0..16 {
        recompose = quote { $recompose + self.bits[$i] * $weight };
        booleanity = quote { assert(self.bits[$i] * (self.bits[$i] - 1) == 0, "bit is not boolean"); };
        weight = weight * 2;
    }
    quote {
        impl $typ {
            fn assert_in_range(self) {
                $booleanity
                assert(self.amount == $recompose, "amount out of 16-bit range");
            }
        }
    }
}

fn main(amount: pub Field, bits: [Field; 16]) {
    let note = Note { amount, bits };
    note.assert_in_range();
}
