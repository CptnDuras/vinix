// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Decorations — the bevel primitive (spec B2).
//
// The core structural primitive of the Blue look: a rectangle with a raised,
// sunken, or grooved edge. A raised edge (light top/left, dark bottom/right)
// reads as "pressable" (buttons, panel faces); a sunken edge reads as "a well"
// (text fields, list boxes); a groove is a two-line incision (dividers). This
// structural depth is what lets the interface be parsed at a glance.
//
// The first cut draws crisp classic edges (smoothing == 0), which is what the
// era looks (BeOS/Platinum/Win2000) used. `smoothing > 0` is reserved for the
// anti-aliased/gradient-eased variant and currently draws the crisp edge; the
// softened path lands with the ramp/chrome work.
//
// Built on Canvas.fill_rect so it inherits the active clip and rounded mask,
// and is unit-testable against an off-screen Canvas without ui2.
module main

enum BevelStyle {
	flat
	raised
	sunken
	groove
}

// bevel_rect draws `width`-pixel edges around (x,y,w,h) in the given style.
// `light` and `dark` are the highlight and shadow colors (typically derived
// from a Decor ramp step). The interior is left untouched — callers fill it
// separately — so a bevel can wrap any content.
//
//   raised : light on top+left,  dark on bottom+right
//   sunken : dark  on top+left,  light on bottom+right
//   groove : a dark line then a light line (a thin incision)
//   flat   : nothing (degenerate)
fn (mut c Canvas) bevel_rect(x int, y int, w int, h int, style BevelStyle, width int, light u32, dark u32, smoothing int) {
	if w <= 0 || h <= 0 || width <= 0 || style == .flat {
		return
	}
	// `smoothing` is reserved for the anti-aliased/gradient-eased edge variant
	// (Blue spec B2). The first cut draws crisp classic edges regardless.
	_ := smoothing
	match style {
		.raised {
			c.draw_bevel_edges(x, y, w, h, width, light, dark)
		}
		.sunken {
			c.draw_bevel_edges(x, y, w, h, width, dark, light)
		}
		.groove {
			// A groove is a 1px dark line just inside a 1px light line: it reads
			// as a scored channel rather than a raised or sunken block.
			c.draw_bevel_edges(x, y, w, h, 1, dark, light)
			if w > 2 && h > 2 {
				c.draw_bevel_edges(x + 1, y + 1, w - 2, h - 2, 1, light, dark)
			}
		}
		.flat {}
	}
}

// draw_bevel_edges paints the top+left edges in `tl` and the bottom+right edges
// in `br`, each `width` thick. Corners belong to the top/left edges, matching
// the classic 3D border look.
fn (mut c Canvas) draw_bevel_edges(x int, y int, w int, h int, width int, tl u32, br u32) {
	// Top edge (full width) and left edge (full height): the `tl` color.
	c.fill_rect(x, y, w, width, tl) // top
	c.fill_rect(x, y, width, h, tl) // left
	// Bottom and right edges: the `br` color. Offset so the top/left corners
	// keep their color, as period 3D borders do.
	c.fill_rect(x, y + h - width, w, width, br) // bottom
	c.fill_rect(x + w - width, y, width, h, br) // right
}
