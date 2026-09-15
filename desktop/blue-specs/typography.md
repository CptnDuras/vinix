# C. Typography

Configurable type. Today the desktop uses one fixed anti-aliased coverage atlas
(`font.v` / `font_data.v`). Blue makes size, weight, and smoothing
configurable, and defers true multi-family choice as the one item that needs
new font *data*, not just code.

Touches: `font.v`, `render.v` (text styles), `settings.v` (`Typography` axis).
Depends on: A (Configuration). Depended on by: G (presets set type).

## Sub-features

1. **Type configuration over the existing atlas.** `Typography{ ui_size,
   ui_weight, title_size, title_weight, smoothing, hinting }` as `?T` fields,
   applied over the current atlas without new glyph data. Ships first. *Deep
   pass defines: how size/weight thread through `render.v` text styles, what
   `smoothing ∈ {none, grayscale, subpixel}` and `hinting` change in the
   rasterizer, and effective defaults.*
   - **Acceptance criteria:** (a) resolved `ui_size`/`title_size` change the
     rendered text-style size for UI and title text respectively; (b)
     `ui_weight`/`title_weight` select the bold coverage where available and
     fall back gracefully otherwise; (c) `smoothing=none` produces 1-bit
     coverage (hard edges), `grayscale` the current AA; (d) all fields default
     to today's appearance when none (no visual regression).
   - **Testing:** unit test asserts the text style emitted for a label reflects
     the resolved size/weight; a test that `smoothing=none` yields coverage
     values in {0,255} only; a golden check that all-none `Typography`
     reproduces today's text styles.

2. **Font data & multiple families *(deferred)*.** `ui_family` / `mono_family`
   selection. Requires generating and embedding additional coverage atlases (the
   existing one is baked into `font_data.v`) — the most expensive single item in
   the whole Blue spec. Fields reserved now, not implemented early. *Deep pass
   defines: atlas generation pipeline, storage/size budget, family-selection
   plumbing — scheduled independently.*
   - **Acceptance criteria (deferred):** (a) a second embedded family renders
     selectable via `ui_family`; (b) an unknown family falls back to the default
     atlas without error; (c) image/initramfs size budget documented and met.
   - **Testing (deferred):** render the same string under two families and
     assert differing coverage; assert unknown-family fallback path.

## Open questions

- Whether subpixel smoothing is worth it: the compositor owns XRGB pixels and
  the M1 presenter may scale 2×, which breaks subpixel order. (Leaning: ship
  `none`/`grayscale` only; reserve `subpixel` unimplemented.)
- Minimum viable family set for the deferred item (one UI + one mono?).
