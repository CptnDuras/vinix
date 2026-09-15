# A. Configuration

The three-state configuration model underlies every other Blue feature. Presets
and user overrides are **sparse optionals**, resolved **field-by-field** into a
single fully-resolved `EffectiveConfig` that the renderer and window manager
read. The renderer never inspects presets or overrides directly.

Resolution order for every axis field:

```
effective(field) = user_override(field)      if set
                 = active_preset.value(field) else if the preset sets it
                 = built-in default           otherwise ("not set" at both levels)
```

"Not set" is a first-class value at both levels. Adding a new field defaults to
"not set" everywhere and therefore inherits the built-in default with no
migration.

Touches: `settings.v` (replaces `ThemeKind` enum and the `Theme` match in
`Desktop.theme()`), new `lookandfeel.v`. Depends on: nothing. Depended on by:
all of B–H.

**Axis set (authoritative, per BLUE.md):** `LookAndFeel` and `Settings` each
carry five optional axis fields — `Decor`, `Typography`, `Behavior`, `Shell`,
`DesktopSurface`. Configuration (A) and the Menu system (F) are not axes; F's
only user knob is `Behavior.menu_placement`.

**Optional representation (decided, was an open question):** each axis is a
struct of `?T` fields (V's option type). "Not set" is the none case. This is
chosen over a sentinel value (ambiguous for colors/ints) and over a parallel
"is-set" bitmask (error-prone). The resolver merges option-by-option.

## Sub-features

1. **Data model.** The shape of `LookAndFeel` (a sparse preset: `id`, `name`,
   `description`, and optional `Decor`/`Typography`/`Behavior`/`Shell`/
   `DesktopSurface`), and of `Settings` (selected `preset_id` string plus
   per-axis optional overrides). Each axis is itself a record of `?T` fields so
   overrides can be partial within an axis. *Deep pass defines: exact V types,
   which fields are optional vs required.*
   - **Acceptance criteria:** (a) `LookAndFeel` and `Settings` compile with
     every axis field as `?T`; (b) a preset that sets no axis is valid and
     resolves to all built-in defaults; (c) an override that sets a single field
     leaves all sibling fields none.
   - **Testing:** unit test constructs a `LookAndFeel{}` with all-none axes and
     asserts field access returns none; constructs a partial override and
     asserts exactly one field is some.

2. **Resolver semantics.** The field-by-field merge producing `EffectiveConfig`.
   Precedence, how partial-within-axis overrides merge, how a fully-resolved
   config is cached and invalidated when a setting changes, and the guarantee
   that the renderer only ever sees resolved values (`EffectiveConfig` has no
   optionals — every field is concrete). *Deep pass defines: the resolver
   function signatures, merge algorithm, caching/dirty strategy.*
   - **Acceptance criteria:** (a) `resolve(preset, overrides) -> EffectiveConfig`
     applies override → preset → default precedence per field; (b)
     `EffectiveConfig` contains no option types; (c) changing one override
     recomputes the effective config and marks the desktop dirty; (d) resolution
     is deterministic (same inputs → identical output).
   - **Testing:** table-driven unit test with (override, preset, default)
     triples per field asserting the winner; a test that `EffectiveConfig` has no
     `?` fields (compile-time by construction); a test that mutating an override
     changes exactly the intended effective fields.

3. **Persistence & migration.** How sparse override state serializes and loads
   (extends existing settings persistence), what "not set" looks like on disk
   (absent key, never a sentinel), reset semantics (clearing an override returns
   the field to preset/default), and migration from the current `ThemeKind` enum
   + `Settings` to a `preset_id` + overrides. *Deep pass defines: on-disk
   format, load/save, forward/backward compatibility, migration path.*
   - **Acceptance criteria:** (a) round-trip save→load of a sparse override set
     preserves exactly the set fields and leaves the rest none; (b) an old
     `ThemeKind`-based settings blob loads as the matching `preset_id` with no
     overrides; (c) "reset this setting" clears the on-disk key and the field
     re-inherits; (d) an unknown/absent key never crashes the loader.
   - **Testing:** round-trip unit test; a migration test feeding a legacy
     settings value and asserting the resulting `preset_id`; a test that a
     truncated/garbage blob loads to defaults rather than panicking.

## Open questions

*(resolved)* Optional representation → `?T` fields (see header). Effective
config → memoized and recomputed on setting change, not per frame (see R2 in
sub-feature 2).
