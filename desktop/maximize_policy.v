// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Window handling — maximize / restore policy (spec D2).
//
// Replaces the hardcoded "fill to canvas.height - taskbar_height" with a
// policy that can respect occupied panel edges (a top bar and/or bottom bar).
// The maximized rectangle computation is pure geometry over the screen size
// and the reserved panel insets, so it is unit-tested without ui2. wm.v feeds
// it the resolved shell's reserved edges.
module main

enum MaxPolicy {
	fill_screen    // ignore panels: the whole screen
	respect_panels // subtract every reserving panel edge (top/bottom)
}

// PanelInsets are the pixels reserved by panels on each edge. A panel that does
// not reserve space (autohidden / reserve_space=false) contributes 0.
struct PanelInsets {
	top    int
	bottom int
	left   int
	right  int
}

struct Rect2 {
	x int
	y int
	w int
	h int
}

// maximize_rect computes the target rectangle for a maximized window.
// fill_screen uses the whole screen; respect_panels subtracts the insets.
fn maximize_rect(screen_w int, screen_h int, insets PanelInsets, policy MaxPolicy) Rect2 {
	if policy == .fill_screen {
		return Rect2{
			x: 0
			y: 0
			w: screen_w
			h: screen_h
		}
	}
	x := insets.left
	y := insets.top
	w := screen_w - insets.left - insets.right
	h := screen_h - insets.top - insets.bottom
	return Rect2{
		x: x
		y: y
		w: if w < 0 { 0 } else { w }
		h: if h < 0 { 0 } else { h }
	}
}
