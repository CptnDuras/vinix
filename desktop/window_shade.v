// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Window handling — window-shade / roll-up (spec D1).
//
// Classic BeOS/Mac WindowShade: collapse a window to just its title bar and
// back. The state transition is pure arithmetic over (height, shaded,
// restore_height_shade) so it can be unit-tested without the ui2-coupled
// Window/WM; wm.v applies it to a real Window.
module main

// ShadeState is the shade-relevant slice of a window's geometry.
struct ShadeState {
mut:
	height              int
	shaded              bool
	restore_height_shade int
}

// shade_toggle collapses the window to `title_height` (storing the current
// height to restore later) or restores the stored height. It is a no-op when
// shading is disabled by the resolved Behavior. Returns the new state.
//
//   not shaded + enabled  -> store height, height = title_height, shaded = true
//   shaded                -> height = restore_height_shade, shaded = false
//   not shaded + disabled -> unchanged
fn shade_toggle(s ShadeState, title_height int, enabled bool) ShadeState {
	mut out := s
	if s.shaded {
		// Unshade: restore the stored height.
		out.height = s.restore_height_shade
		out.shaded = false
		return out
	}
	if !enabled {
		return out // no-op when disabled
	}
	// Shade: remember the current height, collapse to the title bar.
	out.restore_height_shade = s.height
	out.height = title_height
	out.shaded = true
	return out
}

// shaded_body_visible reports whether a window's body (anything below the title
// bar) should be drawn and hit-tested. A shaded window shows only its title.
fn shaded_body_visible(s ShadeState) bool {
	return !s.shaded
}
