# G. Presets & registry

The registry mechanism and the concrete presets that make the reference
environments pure configuration. This is the last deep spec to finalize because
a preset can only be written concretely once the fields of B–F and H are fixed.

Touches: new `lookandfeel.v` (registry), preset files (`blue.v`, era presets),
`settings.v` (`Desktop.theme()` → registry lookup by `preset_id`),
`settings_app.v` (registry-driven picker). Depends on: **A–H** (a preset may set
any of the five axes: Decor, Typography, Behavior, Shell, DesktopSurface).
Depended on by: nothing (top of the stack).

## Sub-features

1. **Registry mechanism.** A single list/map of `LookAndFeel` values keyed by
   stable string `id`; lookup by `Settings.preset_id`; how presets register
   (compile-time list first; runtime-loaded theme files are a later, separate
   feature). Replaces the `ThemeKind` enum and the hardcoded `match` in
   `Desktop.theme()`. *Deep pass defines: the registry type, lookup +
   fallback-when-missing, and the one-line `theme()` change.*
   - **Acceptance criteria:** (a) lookup by a known id returns that preset; (b)
     lookup by an unknown/absent id falls back to a defined default preset (no
     crash); (c) adding a preset needs no change to `Settings` or the picker
     code; (d) `Desktop.theme()`/resolution is driven by the registry, not a
     `match`.
   - **Testing:** unit test for known-id and unknown-id lookup; a test that a
     newly appended registry entry appears in the resolved set without other
     edits.

2. **Reference presets.** Each a *sparse* `LookAndFeel` setting only the axes
   that define its character. Axes not mentioned are none (inherit defaults).
   - **Blue** — flagship; `Decor` (ramp + soft bevels), `Typography` (AA),
     `Shell` + `DesktopSurface` per the flagship design choice (BLUE.md open
     questions); `Behavior.menu_placement = global`.
   - **Windows 2000** — `Shell`: one bottom `full_bar` with window_list;
     `Behavior.menu_placement = in_window`; `Decor`: raised/sunken bevels, blue
     gradient title.
   - **Platinum** — `Shell`: one top `full_bar`, no window_list;
     `Behavior.menu_placement = global`; `Decor`: cool gray, pinstripe title,
     grooves.
   - **BeOS** — `Shell`: one corner panel folding system_menu + window_list;
     `Behavior.menu_placement = in_window`; `Decor`: restraint, tight spacing,
     tab title.
   - **Default** — current bottom taskbar, migrated unchanged (no regression);
     `Behavior.menu_placement = none`.
   - **macOS** — current dock, migrated unchanged; `menu_placement = none`.
   *Deep pass defines: each preset's exact field set, once B–F and H fields
   exist.*
   - **Acceptance criteria:** (a) each preset is sparse (unset axes are none);
     (b) Default and macOS resolve to today's exact appearance and behavior
     (no regression); (c) each preset resolves without error and produces a
     complete `EffectiveConfig`.
   - **Testing:** golden test that Default and macOS resolved configs reproduce
     the current themes field-for-field; a test that every registered preset
     resolves to an option-free `EffectiveConfig`.

3. **Settings / picker UI.** The Settings pane iterates the registry (one choice
   per preset, using each preset's `name`/`description`), replacing the current
   hardcoded Default/macOS choices and description branches. Plus panes for
   overriding each axis, and — recommended — a visual "inherited vs overridden"
   indication with per-setting reset. *Deep pass defines: the pane layout, the
   override controls per axis, and how the picker reflects resolver state.*
   - **Acceptance criteria:** (a) the picker lists exactly the registered
     presets in display order; (b) selecting a preset updates `preset_id` and
     re-resolves live; (c) an overridden setting shows as overridden with a
     working reset that returns it to inherited; (d) no preset name/description
     is hardcoded in the pane.
   - **Testing:** assert the picker's choice elements match the registry
     entries; assert selecting a preset changes the resolved config; assert
     reset clears the override and the field re-inherits (ties to A3 reset test).

## Open questions

- Registration order vs. display order (id is the stable key; add an explicit
  `order` field). 
- How much per-axis override UI ships initially vs. preset-only selection first.
- Whether "Default"/"macOS" keep their names or are rebranded under Blue.
