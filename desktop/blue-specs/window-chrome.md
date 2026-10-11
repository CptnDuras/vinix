# B5. Window chrome model (`Chrome`): shapes, widgets, skins

Extends B3 (decorations.md). B3 says "chrome geometry is owned by Decor" but
today `wm.v:window_element` hardcodes it: one full-width title bar, exactly
three buttons (close/minimise/zoom), a `ButtonLook` of `flat|traffic`, a left
or right `button_side`. Presets can only recolour that. This spec replaces the
hardcoding with a data model, so a preset (or a skin file) can describe a
BeOS tab, a Win2k bar, a Platinum bar with a zoom box and a collapse box, a
macOS toolbar title, and so on, without touching `wm.v`.

## Goals

1. **Title bar shape.** The bar is not necessarily the window width. BeOS has a
   yellow *tab* that is shorter than the window, sits at the top-left, with the
   rest of the top edge being thin frame. Tab width can be fixed, fit-to-title,
   or a fraction of the window, and may be left/center/right aligned.
2. **Widgets as data.** Any number of widgets, each with a kind, an action, a
   position, a size, and an appearance per state. Close, minimise, maximise,
   shade, stick/pin, window menu, "always on top", resize grip, and a custom
   action slot are all just entries.
3. **Skins.** Every drawable (bar background, tab, frame edge, widget face) can
   be a procedural fill (today's behaviour), a **bitmap** (9-slice), or a
   **vector** (path list), chosen per element and per state.
4. **No regressions.** Every shipped preset must resolve to a chrome that
   renders pixel-identical to today. The default `Chrome` is derived from the
   existing `Theme` fields; only presets that opt in change.

## Data model (all sparse `?T`, same resolver rules as the other axes)

```
ChromeConfig {            // new optional axis payload inside DecorConfig
    bar        ?BarShape
    frame      ?FrameSpec
    widgets    ?[]WidgetSpec   // replaces button_side / ButtonLook / 3 fixed buttons
    skin       ?SkinRef        // optional: a skin supplies the drawables below
}

BarShape {
    kind       TitleKind       // .full | .tab
    extent     Extent          // .fixed(px) | .fit_title(min,max,pad) | .fraction(f)
    align      TitleAlign      // where the tab sits along the top edge (left|center|right)
    height     int
    overlap    int             // tab overlaps the frame by n px (BeOS)
    corner     CornerSpec      // per-corner radius: tl, tr, bl, br
    slant      int             // 0 = square; >0 = BeOS-style angled edge
    text_align TitleAlign      // title inside the bar
}

FrameSpec { width int; edge_style BevelStyle; resize_grip ?GripSpec; ... }

WidgetSpec {
    id        string           // 'close','zoom','shade','menu','stick', or custom
    action    WidgetAction     // .close .minimize .maximize .shade .stick .menu
                               // .always_on_top .none  (+ future: .custom)
    anchor    Anchor           // .bar_left .bar_right .bar_center .frame_tl ... 
    order     int              // sort within the anchor
    size      Size             // w,h (own size, not button_size)
    margin    Insets
    visible   WidgetVisibility // .always | .when_focused | .on_hover | .when(cond)
    states    WidgetStates     // normal / hover / pressed / disabled / inactive
}

WidgetStates { normal, hover, pressed, disabled, inactive : DrawSpec }

DrawSpec  = Fill(color, radius, border)           // procedural (today)
          | Glyph(builtin name, color)            // today's strokes
          | Bitmap(asset, slice, tint?)           // new
          | Vector(asset, fill, stroke, tint?)    // new
          | Stack([DrawSpec])                      // layers (face + glyph)
```

`TitleKind.tab` is what makes BeOS right: the bar is `extent` wide, positioned
by `align`, and the window body's top edge is a thin `frame` (the "tab" sits on
it, `overlap` px over). `.full` is every other preset.

### Widget layout

Widgets are placed by anchor then `order`, each advancing the cursor by its own
size + margin, so mixed sizes work (Platinum's zoom box is not the same size as
its close box). `WidgetAction` drives hit-testing and behaviour; the existing
`window.id_close`/`id_minimize`/`id_maximize` ids become `win.<id>.w.<widget id>`
and `hit` routing maps a widget to its action. `shade` already exists (D1).

Default widget list = what `window_element` builds today (derived from
`button_look`, `button_side`, `button_size`, `button_gap`, `button_inset`,
`traffic_*`). `ButtonLook`/`traffic_*` stay as named *stock* widget styles.

## Skins

Two asset kinds, both decoded by tiny in-tree decoders because Vinix has no
PNG/JPEG/SVG decoder (wallpapers arrive pre-decoded, glyphs are strokes):

- **Bitmap**: a straightforward uncompressed format (proposal: PAM/`P7`
  RGB_ALPHA, or a 12-byte header + premultiplied BGRA) plus a **9-slice** spec
  `{left, top, right, bottom}` so a bar/tab/frame scales without distortion.
  Tools convert PNG -> this at build time (`desktop/tools/`), like wallpapers.
- **Vector**: a small SVG-path subset (`M L C Q Z`, fill/stroke, solid colour or
  linear gradient), rasterised by the existing canvas AA routines
  (`corner_coverage`, `blend`) and cached per (asset, size, state, scale).
  Vectors suit widgets (scale-correct at any `size`) and tab shapes with a slant.

A **skin** is a directory (or a single archive) holding `skin.cfg` (same
`key=value` grammar as preferences.v) plus the asset files, selecting
`ChromeConfig` values by id and naming drawables per element/state. Skins load
from `/usr/share/vinix/skins/<id>/` and `~/.config/vinix/skins/<id>/`, and each
appears in the theme picker next to the built-in presets (a skin is just a
`LookAndFeel` whose `decor.chrome` came from a file). A broken asset falls back
to the procedural drawable for that element rather than failing the skin.

Every new field gets an `ov_*`-style override only when the Settings UI exposes
it; skin-defined values do not need persistence keys.

## Panels (top/bottom bars)

The top/bottom bars are still not right. They should reuse the same machinery
rather than being a separate hardcoded path: a panel is `{edge, thickness, inset,
float (dock-style centred capsule vs full width), skin DrawSpec, items[]}` with
items = start button, window list, launcher pins, tray, clock, global menu.
Specific defects to be enumerated in a separate pass against screenshots (see
"Open questions").

## Build order

1. **Model + derive-default**: `ChromeConfig`, resolver, and
   `chrome_from_theme(Theme)` so today's output is reproduced; refactor
   `window_element`/`title_button`/hit-testing to read it. Tests: pixel/tree
   equality with current output for every preset; widget order/anchor tests.
2. **Tab bars**: `TitleKind.tab`, extent/align/overlap/slant; BeOS preset uses a
   short yellow tab; hit-testing and drag area follow the tab shape.
3. **Widget set**: configurable list/size/visibility/state styling; add `shade`,
   `stick`, `menu` widgets; per-preset lists (Platinum zoom+collapse boxes,
   BeOS zoom + minimise-style, Win2k three squares).
4. **Vector skins**: path parser, rasteriser + cache, `Vector` DrawSpec.
5. **Bitmap skins**: decoder, 9-slice blitter, `Bitmap` DrawSpec, converter tool.
6. **Skin loader + picker integration**, then panel rework on the same base.

## Open questions

- Skin container: loose directory vs one archive (`.vskin` tar)? (Leaning:
  directory first; the initramfs already ships tar.)
- Does a skin may replace *app-interior* controls (buttons, scrollbars), or only
  window chrome + panels? (Leaning: chrome + panels now.)
- Third-party skin trust: skin files are data only (no code), so loading needs
  size/bounds validation, not sandboxing.
- Settings UI: per-axis overrides for the common knobs (tab vs full bar, widget
  side, widget set preset) now; full widget editor later.
