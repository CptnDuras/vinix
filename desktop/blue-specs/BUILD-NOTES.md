# Blue build/verification notes

## V toolchain

The Vinix desktop's compile-time `$vml` system (used by the built-in
Calculator) is tightly coupled to a specific V compiler + ui2 pair. The
authoritative pins are in `.github/workflows/nightly.yml`:

- `V_COMMIT   = d622f33b527b88ef6707ad72a65bf084ba96d792`
- `UI2_COMMIT = d13259f6167367ad8ebd6b2aa4a1f35c59bb1551`

To build V at the pinned commit, the companion `vc` bootstrap repo must be
reset to the matching commit before `make`, otherwise the bootstrap fails with
`map method reserve should be lowered by v3 transform`:

```sh
cd <v-checkout>
git -C vc checkout 1bdb769f   # the vc commit embedding V d622f33b
git checkout d622f33b
rm -f v v1 && make v
```

## Verifying Blue

Blue's model/logic is deliberately free of any ui2 dependency and is verified
with the base compiler via:

```sh
sh desktop/tools/test-blue.sh
```

This compiles and runs the whole Blue pure-logic suite (configuration &
resolver, gray ramp, panel layout, bevel primitive, window-shade, maximize
policy, focus model, menu model) — 8 test files. It passes under the pinned V
d622f33.

## Known blocker: full desktop `$vml` harness

`desktop/tools/test-utilities.sh` (and the other `$vml`-based harnesses) do not
currently compile with the pinned V d622f33 + pinned ui2 d13259f in this
environment. Root cause, reproduced with a minimal probe:

- The Linux/Vinix headless build supplies `ui2.bounds()` (the `$vml` root bound
  function) through `desktop/tools/ui2_headless_bounds.v`, guarded by
  `$if linux && ui2_headless ? { ... }`.
- Under the pinned V, that guarded block is **not compiled in** even when
  `-d ui2_headless` is passed: `ui2.bounds()` resolves to a void/absent
  function, so `calculator_app.v`'s `$vml` expansion fails
  (`unknown function ui2.bounds` / `bounds() returns 0 values`).
- Removing the `?` makes V reject `ui2_headless` as an unknown ident, and
  nesting the guards does not help — the custom compile-time flag block is not
  activating.

This is a change in how this V evaluates user-defined `$if <flag> ?` blocks
versus the version the Vinix headless shim was written for. Resolving it needs
a rework of the headless `bounds()` shim mechanism (out of scope for Blue), or
a V commit whose `$if custom_flag ?` semantics match the shim.

Consequently, the ui2-coupled Blue glue (beveled chrome drawing, panel tree
assembly, menu popups, input wiring) cannot be integration-tested here; its
underlying decisions are all covered by the pure-logic suite above.
