/*
Challenge 09 -- Selector Spacing Bypass

Protocol: Aztec-style account entrypoint, gated by function selector
Prover:   A user invoking one of the account's entrypoints
Verifier: The account, which FORBIDS the privileged `set_admin` entrypoint
Flow:     Each entrypoint's selector is its canonical signature, built at compile
          time from the function's own tokens (name + argument types) and
          assembled into a string with `as_quoted_str`. The account's deny-list
          names the forbidden signature, and the generated guard admits an
          entrypoint iff its selector is NOT on the deny-list.

The account exposes two entrypoints, both taking (Field, Field):
    #0  pay(recipient, amount)      -- user-level   (allowed)
    #1  set_admin(new_admin, key)   -- privileged   (FORBIDDEN)

The only public input is `entrypoint` -- which entrypoint is being invoked.
*/

// Registry of entrypoint selector signatures, in declaration order, populated
// at compile time by the `#[entrypoint]` attribute below.
comptime mut global REG: [Quoted] = [];

// Build a function's canonical signature string "name(type, type, ...)" from
// its tokens: start with the name, then append each parameter type.
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
        let ty = params[i].1;
        sig = quote { $sig $ty };
    }
    sig = quote { $sig $closing_bracket };
    f"{sig}".as_quoted_str()
}

#[entrypoint]
pub fn pay(_recipient: Field, _amount: Field) {}

#[entrypoint]
pub fn set_admin(_new_admin: Field, _key: Field) {}

comptime fn entrypoint(f: FunctionDefinition) {
    REG = REG.push_back(entrypoint_signature(f));
}

// The account forbids `set_admin`. Generate `assert_allowed`: admit entrypoint
// `e` iff its selector is not the forbidden signature.
#[generate_guard]
pub struct Account {}

comptime fn generate_guard(_s: TypeDefinition) -> Quoted {
    // the account's deny-list: the canonical signature of the forbidden entrypoint
    let forbidden = quote { "set_admin(Field,Field)" };
    let mut allowed = quote { false };
    for i in 0..REG.len() {
        if !(REG[i] == forbidden) {
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
