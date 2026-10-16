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

## Full desktop `$vml` harness (RESOLVED)

`desktop/tools/test-utilities.sh` and the other `$vml`-based harnesses now
compile and run under the pinned V d622f33 + pinned ui2 d13259f, after fixing
the headless `bounds()` shim (`desktop/tools/ui2_headless_bounds.v`).

**Root cause (was blocking):** the shim supplied `ui2.bounds()` (the `$vml`
root bound function) via `$if linux && ui2_headless ? { ... }`. Under the pinned
V, a `$if` that combines a built-in target (`linux`) with a user-defined `?`
flag does not compile its block in even with `-d ui2_headless`; nor does a
nested built-in/custom pair. Only a single custom `?` flag activates. Isolated
with minimal probes.

**Fix:** guard the shim with `$if ui2_headless ? { ... }` alone. The headless
desktop is Linux-only, so gating on the flag is correct.

**Result:** `test-utilities.sh` reports 43/44 passing, including every test that
exercises Blue's changes (theme picker, taskbar, app-process protocol). The one
failure, `test_terminal_renders_pty_echo_and_carriage_return_updates`, is a
pre-existing environment-dependent PTY-echo test that fails identically at the
pre-Blue commit and is unrelated to this work.
