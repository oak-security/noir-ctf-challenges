/*
Challenge 08 -- Comptime Range Gadget (PATCHED)

The booleanity fragment now ACCUMULATES across loop iterations: each step
prepends `$booleanity` so the previous bits' constraints are preserved instead
of overwritten. With all 16 booleanity constraints emitted, every "bit" is
forced to 0 or 1, the recomposition is a genuine 16-bit range proof, and an
out-of-range amount can no longer be smuggled through a free coefficient.
*/

// A confidential note: a public `amount` and its 16-bit witness decomposition.
#[range_gadget]
struct Note {
    amount: Field,
    bits: [Field; 16],
}

// Compile-time range-check generator. Walking the 16 bits, it accumulates BOTH
// the little-endian recomposition of `self.amount` AND the per-bit booleanity
// constraints, then emits an `assert_in_range` that enforces both in full.
comptime fn range_gadget(s: TypeDefinition) -> Quoted {
    let typ = s.as_type();
    let mut recompose = quote { 0 };
    let mut booleanity = quote {};
    let mut weight: Field = 1;
    for i in 0..16 {
        recompose = quote { $recompose + self.bits[$i] * $weight };
        booleanity = quote {
            $booleanity // <- FIXED: prepend `$booleanity` so the per-bit checks accumulate instead of overwriting
            assert(self.bits[$i] * (self.bits[$i] - 1) == 0, "bit is not boolean");
        };
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
