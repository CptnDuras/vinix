# B. Decorations (`Decor`)

The visual theme of windows and chrome. Supersedes the current `Theme` struct in
`settings.v` by **embedding** it (so upstream changes to `Theme` merge cleanly)
and adding the gray-ramp and bevel vocabulary on top.

Touches: `settings.v`/`theme.v` (`Decor` around `Theme`), `canvas.v` (bevel
primitive), `wm.v` + `render.v` (chrome reads `Decor`). Depends on: A
(Configuration). Depended on by: E (panels use ramp/bevels/icon-tile), F (menus
use ramp/bevels), G (presets author `Decor`), H (desktop icons use the shared
icon-tile renderer).

**`theme.v` migration note (shared with H, ISSUES.md ISSUE-6):** `theme.v`'s
color/measurement constants migrate into `Decor`; its *shortcut-geometry*
constants migrate into the `DesktopSurface` axis (H3). Neither B nor H "owns"
`theme.v`; each removes its own constants into its axis, so the edits do not
collide.

**Shared icon-tile renderer (ISSUES.md ISSUE-3):** the single `icon_tile`
renderer (app glyph + label + hover/press states) is a **visual primitive owned
here in B**. The Shell launcher (E4) and the desktop icons (H2/H3) are two
*hosts* that place `icon_tile`s; they share this renderer but keep independent
placement and pinned-set models.

## Sub-features

1. **Palette & gray ramp.** A tuned neutral scale with a faint, consistent
   temperature; surfaces, edges, hover shades, and shadows are *derived* from
   ramp steps rather than chosen independently, so retuning the ramp restyles
   the system coherently. A single reserved `accent` (+`accent_dim`). *Deep pass
   defines: number of steps, exact temperature/hex proposal, the derivation
   rules (which step maps to body / panel / well / edge / hover).*
   - **Acceptance criteria:** (a) a `Ramp` of N steps + accent produces every
     chrome surface color by rule, not by literal; (b) changing one ramp
     definition changes all derived surfaces consistently; (c) derived
     light/dark bevel pairs come from the ramp, not separate constants.
   - **Testing:** unit test asserts `surface(role)` returns the expected ramp
     step per role; a test that swapping the ramp changes body/panel/well colors
     together.

2. **Bevel primitive (`canvas.v`).** `bevel_rect(rect, style, width, light,
   dark, smoothing)` with `style ∈ {flat, raised, sunken, groove}`. `raised` =
   light top-left / dark bottom-right (buttons, faces); `sunken` = inverse
   (fields, wells); `groove` = two-line incision (dividers). `smoothing` = 0 is
   crisp 1px classic; >0 is anti-aliased/gradient-eased over the existing
   `blend`/`mix`/`corner_coverage`. *Deep pass defines: exact signature, edge
   raster math, interaction with the existing clip/rounded-mask, perf notes.*
   - **Acceptance criteria:** (a) `raised` and `sunken` of the same rect are
     pixel-inverses of each other at `smoothing=0`; (b) the fill obeys the
     active clip and rounded mask; (c) `smoothing=0` touches only edge pixels of
     the given `width`; (d) `flat` degenerates to a plain rect fill.
   - **Testing:** render into an off-screen `Canvas` and assert edge pixels:
     top-left == light, bottom-right == dark for `raised`, inverted for
     `sunken`; assert interior pixels untouched; assert pixels outside the clip
     unchanged. (Matches the existing off-screen element-tree test style.)

3. **Window chrome.** How `Decor` fields drive `wm.v`'s title bar, buttons,
   corners, and shadow: retained `Theme` fields (`title_active_bg`→`bg2`
   gradient, `button_look`, `window_radius`, `shadow_alpha`) plus new
   `border_style`, `bevel_width`, `bevel_smoothing`, and a `beveled` button look.
   **`title_align ∈ {left, center, right}`** replaces the old `title_centered`
   bool (3-way, parity with xfwm4 — ISSUES.md GAP-9; `title_centered` maps to
   `center` during migration). Square vs rounded = `window_radius == 0`. **Chrome
   geometry — including the geometry of any title-bar buttons — is owned here
   (ISSUES.md ISSUE-4).** *Which* logical buttons exist and their order is a
   `Behavior` field (D3); B3 only draws them. A window-menu button, if present in
   the set, is drawn here and triggers F3's menu.
   - **Acceptance criteria:** (a) chrome reads only resolved `Decor` (no
     literals in `wm.v`); (b) `window_radius==0` yields square corners,
     `>0` rounded; (c) the button set from D3 renders in order with B3's chosen
     look; (d) focused vs unfocused colors derive from the ramp; (e)
     `title_align` places the title left/center/right.
   - **Testing:** build the window element tree with a given `Decor` + button
     set and assert the title-bar children (ids, order, colors) match; assert
     square vs rounded via the box style radius; assert unfocused derives its
     title color from the ramp step, not a literal; assert title x-position per
     `title_align`.

4. **Cursor appearance.** Fold the compositor's existing cursor constants
   (`cursor_fill` / `cursor_edge` in `theme.v`) into `Decor` so the pointer is
   themable per preset (ISSUES.md GAP-11 — XFCE themes cursors separately; Vinix
   draws its own cursor, so it belongs in `Decor`). Scope: cursor *colors* and
   size now; a full swappable cursor *shape set* is out of this cut. *Deep pass
   defines: the cursor `Decor` fields and the migration of the constants.*
   - **Acceptance criteria:** (a) cursor color/size come from resolved `Decor`;
     (b) a preset can change the cursor without touching code; (c) default
     reproduces today's cursor exactly.
   - **Testing:** assert the cursor is drawn with the resolved `Decor` values;
     assert all-default reproduces today's `cursor_fill`/`cursor_edge`.

## Open questions

- Do dividers/group boxes in *app interiors* also use `groove`, or only chrome?
  (Leaning: chrome + Settings panes now; app interiors opt in later.)
- Whether shadow color is a ramp step or independent. (Leaning: darkest ramp
  step at `shadow_alpha`.)
