# Window skins

A skin is the artwork for a window's title bar and its controls. Settings >
Appearance > Skin lists them; a look can wear one of its own (BeOS, NeXTSTEP,
Amiga, CDE, Windows 3.1 and Haiku do) and the user can put any on any look. A
skin changes how things are drawn, never what they do: the controls and where
they sit come from the look, or from what the user arranged on the title bar
designer, unless the skin's own `chrome.*` lines say otherwise.

## Where skins live

| Where | What |
| --- | --- |
| compiled in (`skin_builtin.v`) | the skins of the shipped looks, as text |
| `/usr/share/vinix/skins/<id>/` | installed with the system, listed in `index.txt` |
| `/root/.vinix-skins/<id>/` | the user's own; a new folder shows up in Settings at once |

`VINIX_USER_SKIN_DIR` and `VINIX_SKIN_DIR` move the last two, which is how a skin
author points the desktop at a checkout. A skin's id is its folder name, from
`a-z`, `0-9`, `-` and `_`, at most 32 characters. A folder of the user's with the
name of a compiled-in skin is ignored; one with the name of an installed skin
stands in for it.

## skin.cfg

One `key=value` per line; blank lines and lines starting with `#` are ignored. An
unknown key or a bad value is skipped and the rest still applies.

```
name=My skin

# What a control looks like, by action and state.
widget.close=vector:cross.svg
widget.close.hover=vector:cross.svg:#ff4040
widget.close.size=14
widget.maximize=bitmap:zoom.png
widget.shade=fill:#336699

# The bar behind the title.
bar.active=bitmap:bar_active.png:4,4,4,4
bar.inactive=bitmap:bar_inactive.png:4,4,4,4

# Optionally, the shape of the bar and which controls it has.
chrome.kind=tab
chrome.tab_sizing=fit
chrome.tab_slant=5
chrome.widgets=close@leading,maximize@trailing
```

**Controls** are `close`, `minimize`, `maximize`, `shade` (roll up) and `menu`. A
control's state is `normal`, `hover`, `pressed` or `inactive`; a line with no
state sets all four, and a state with no drawable of its own uses `normal`. A
control a skin does not name keeps the look's own face.
`widget.<name>.size` is the control's side in pixels (6 to 64).

**Drawables** are

* `fill:#rrggbb`, a flat colour;
* `vector:<file>[:#rrggbb]`, an SVG (or the plain path text below), filled in the
  colour given, or in the look's glyph colour when none is;
* `bitmap:<file>[:left,top,right,bottom]`, a PNG, stretched as a nine-slice with
  those edges kept unstretched (all zero stretches the whole picture).

**chrome.\*** takes `kind` (`full` or `tab`), `tab_sizing` (`fit`, `fixed`,
`fraction`), `tab_px`, `tab_pct`, `tab_align` (`left`, `center`, `right`),
`tab_pad`, `tab_overlap`, `tab_slant`, and `widgets`, a comma list of
`<control>@leading` or `<control>@trailing`, outermost first, at most seven.

## Files

A skin names plain files in its own folder: letters, digits, `-`, `_` and `.`,
not starting with a dot, at most 64 characters and 2 MB each. No paths.

**SVG** is read as an icon, not as a document. Supported: the shapes `path` (every
command, arcs included), `rect` (with `rx`, `ry`), `circle`, `ellipse`, `polygon`
and `polyline`; the `viewBox` (or `width` and `height`); `transform` on a shape or
a `<g>` with `translate`, `scale`, `rotate` and `matrix`. Everything is filled
with one colour by the non-zero rule, so strokes, gradients, opacity, `evenodd`,
text and filters are not drawn. A shape with `fill="none"` (including one that
inherits it, as stroke icons set on the root) is left out, as is anything in
`<defs>`, `<clipPath>`, `<mask>` or `<style>`. To turn an outline into something
fillable, convert strokes to paths in your editor first (Inkscape: *Path > Stroke
to Path*). A file with nothing it can draw is refused whole and the control keeps
the look's own face.

A hole is a second contour wound the other way, so draw a ring as an outer circle
and an inner one with the opposite direction (in most editors: combine them with
*Path > Difference*).

**PNG** is decoded as RGBA, at most 1024 by 1024. The older `.vbm` bitmap and the
path-text `.vec` vector (`viewbox 12 12` then `path M0 0 H12 …` lines) still
work, and `desktop/tools/png2vbm.py` makes a `.vbm` from a PNG.

## Trying one

Make `/root/.vinix-skins/mine/` with a `skin.cfg` and its files, open Settings >
Appearance > Skin, and pick it. Select a look first: choosing a look sets the
skin to the look's own, and the skin you pick afterwards wears over it. *Reset to
the look* takes it off again.
