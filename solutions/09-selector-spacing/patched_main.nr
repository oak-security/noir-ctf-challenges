/*
Challenge 09 -- Selector Spacing Bypass (PATCHED)

The deny-list is no longer a hand-written string. The forbidden entrypoint is
marked with a `#[forbidden]` attribute, so ITS selector is computed by the same
`entrypoint_signature` routine as every other selector and pushed into a
`FORBIDDEN` list. The guard then allows an entrypoint iff its selector is not in
that list. Because both sides are produced by the one routine, the spacing
matches by construction -- there is no separately-written string to drift from
the real selectors.

(The principled rule: derive every signature through ONE routine and compare
those, never a token-built signature against a hand-written one.)
*/

comptime mut global REG: [Quoted] = [];          // entrypoint selector signatures
comptime mut global FORBIDDEN: [Quoted] = [];    // forbidden selector signatures

comptime fn entrypoint_signature(f: FunctionDefinition) -> Quoted {
    let name = f.name();
    let params = f.parameters();
    let opening_bracket = quote { ( };
    let closing_bracket = quote { ) };
    let comma = quote { , };
    let mut sig = quote { $name $opening_bracket };
    for i in 0..params.len() {
        if i != 0 {
            sig = quote { $sig $comma };
        }
        let ty = params[i].typ();
        sig = quote { $sig $ty };
    }
    sig = quote { $sig $closing_bracket };
    f"{sig}".as_quoted_str()
}

comptime fn entrypoint(f: FunctionDefinition) {
    REG = REG.push_back(entrypoint_signature(f));
}

// the forbidden function's selector is derived by the SAME routine as every
// other selector, so its spacing matches -- no hand-written deny-list string.
comptime fn forbidden(f: FunctionDefinition) {
    FORBIDDEN = FORBIDDEN.push_back(entrypoint_signature(f));
}

#[entrypoint]
pub fn pay(_recipient: Field, _amount: Field) {}

#[entrypoint]
#[forbidden] // <- FIXED: mark the forbidden entrypoint instead of comparing against a hand-written string
pub fn set_admin(_new_admin: Field, _key: Field) {}

#[generate_guard]
pub struct Account {}

comptime fn generate_guard(_s: TypeDefinition) -> Quoted {
    // admit an entrypoint iff its selector is not in the FORBIDDEN list
    let mut allowed = quote { false };
    for i in 0..REG.len() {
        let mut is_forbidden = false;
        for j in 0..FORBIDDEN.len() {
            if REG[i] == FORBIDDEN[j] {
                is_forbidden = true;
            }
        }
        if !is_forbidden {
            allowed = quote { $allowed | (entrypoint == $i) };
        }
    }
    quote {
        fn assert_allowed(entrypoint: u32) {
            assert($allowed, "entrypoint is forbidden");
        }
    }
}

fn main(entrypoint: pub u32) {
    assert(entrypoint < 2, "unknown entrypoint");
    assert_allowed(entrypoint);
}
