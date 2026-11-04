# Solution: 09 Selector Spacing Bypass

## Bug

The account compares two signature strings to enforce its deny-list, and builds
them two different ways.

Each entrypoint's selector is built from the function's **tokens** by
`entrypoint_signature`:

```rust
comptime fn entrypoint_signature(f: FunctionDefinition) -> Quoted {
    let name = f.name();
    let params = f.parameters();
    let opening_bracket = quote { ( };
    let closing_bracket = quote { ) };
    let comma = quote { , };
    let mut sig = quote { $name $opening_bracket };
    for i in 0..params.len() {
        if i != 0 { sig = quote { $sig $comma }; }
        let ty = params[i].typ();
        sig = quote { $sig $ty };
    }
    sig = quote { $sig $closing_bracket };
    f"{sig}".as_quoted_str()
}
```

`sig` is a `Quoted` token stream, and a `Quoted` **stringifies with a space
between every token** (the same padding that makes `bits[0]` print as
`bits [ 0 ]`). So `as_quoted_str` produces, for `set_admin`:

```
"set_admin ( Field , Field )"     <- spaces between every token
```

But the deny-list entry in `generate_guard` is written as a plain string literal — the canonical signature, with no spaces:

```rust
let forbidden = quote { "set_admin(Field,Field)" };   // <- no spaces
```

The guard admits an entrypoint iff its selector is **not** the forbidden one:

```rust
for i in 0..REG.len() {
    if !(REG[i] == forbidden) {             // Quoted string equality
        allowed = quote { $allowed | (entrypoint == $i) };
    }
}
```

`"set_admin ( Field , Field )" != "set_admin(Field,Field)"` — the strings differ
only in whitespace, but they differ. So `set_admin`'s selector is
never equal to the deny-list entry, the guard treats it as *not forbidden*, and
folds `(entrypoint == 1)` into the allowed set:

```rust
fn assert_allowed(entrypoint: u32) {
    assert(false | (entrypoint == 0) | (entrypoint == 1), "entrypoint is forbidden");
}
```

The forbidden `set_admin` passes a guard that was supposed to block it.

## Exploit

```toml
entrypoint = "1"
```

Invoke entrypoint **#1** (`set_admin`). Its token-built selector carries padding
spaces that the hand-written deny-list entry lacks, so the deny-list never
matches it and the proof verifies — a forbidden call goes through. The honest
case (`entrypoint = 0`) still works.

## Fix

Don't hand-write the deny-list string at all. Mark the forbidden function with a
`#[forbidden]` attribute, so *its* selector is computed by the same
`entrypoint_signature` routine and pushed into a `FORBIDDEN` list. The guard
admits an entrypoint iff its selector is not in that list. Both sides are built
by the same routine, so the spacing matches by construction.

```diff
+comptime mut global FORBIDDEN: [Quoted] = &[];

+comptime fn forbidden(f: FunctionDefinition) {
+    FORBIDDEN = FORBIDDEN.push_back(entrypoint_signature(f));
+}

 #[entrypoint]
+#[forbidden] // <- FIXED: mark the forbidden entrypoint instead of comparing against a hand-written string
 pub fn set_admin(_new_admin: Field, _key: Field) {}

 comptime fn generate_guard(_s: TypeDefinition) -> Quoted {
-    let forbidden = quote { "set_admin(Field,Field)" };
     let mut allowed = quote { false };
     for i in 0..REG.len() {
-        if !(REG[i] == forbidden) {
+        let mut is_forbidden = false;
+        for j in 0..FORBIDDEN.len() {
+            if REG[i] == FORBIDDEN[j] { is_forbidden = true; }
+        }
+        if !is_forbidden {
             allowed = quote { $allowed | (entrypoint == $i) };
         }
     }
     ...
 }
```

Now `set_admin`'s entry in `FORBIDDEN` is byte-identical to its entry in `REG`
(both `"set_admin ( Field , Field )"`, built by the same routine), so it matches,
index 1 is dropped from the allowed set, and `assert_allowed` becomes
`assert(false | (entrypoint == 0))`. The exploit (`entrypoint = 1`) is rejected;
the honest `pay` call (`entrypoint = 0`) still verifies. The full patched circuit
is in [`patched_main.nr`](./patched_main.nr); to test it, copy it over
`challenges/09-selector-spacing/src/main.nr` and run `./verify.sh`.

## Additional context

Bug class: **non-canonical signature / spacing mismatch in compile-time string
building**. The flaw is not in the hash or the guard logic — it is that one
side of an equality check is a token-built string (space-padded) and the other
is hand-written (compact), so two representations of the *same* signature never
match.

A `Quoted` is a token stream, and stringifying it inserts a single space between
tokens; there is no canonical spacing unless you impose one. This is documented
behavior, not a quirk — from the Noir
[Metaprogramming docs](https://noir-lang.org/docs/noir/concepts/comptime):

> "formatting a quoted value with multiple tokens will always insert a space
> between each token. If this is undesired, you'll need to only operate on quoted
> values containing a single token."

When signatures, selectors, domain separators, or any hashed/compared strings
are assembled at compile time:

- Derive every instance through **one** canonicalization routine. Never compare
  a token-built string against a hand-written literal — they will disagree
  on spacing.
- Pin the exact byte form (spacing, separators, casing) and, ideally, build it
  by iterating tokens (`Quoted::tokens`) so the spacing is deliberate.
- A deny-list / allow-list keyed on a string is only as sound as the guarantee
  that both sides produce byte-identical strings for the same input.
