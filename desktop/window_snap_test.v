// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Acceptance tests for Blue window snapping (spec D5). Pure geometry, no ui2.
module main

const snap_screen_w = 1280
const snap_screen_h = 800

// (a) A window dragged within snap_distance of a screen edge snaps flush.
fn test_snaps_to_screen_edge() {
	cfg := SnapConfig{
		to_edges: true
		distance: 12
	}
	// Left edge 6px from the work-area left (0): snaps to 0.
	x, y := snap_position(6, 300, 400, 200, snap_screen_w, snap_screen_h, PanelInsets{},
		[]Rect2{}, cfg)
	assert x == 0
	assert y == 300 // nothing near in y, unchanged
}

// respects reserved panel insets: the top edge snaps to the work-area top, not 0.
fn test_snaps_to_work_area_under_top_bar() {
	cfg := SnapConfig{
		to_edges: true
		distance: 12
	}
	insets := PanelInsets{
		top:    26
		bottom: 46
	}
	// y=30 is 4px below the work-area top (26): snaps to 26.
	_, y := snap_position(400, 30, 300, 200, snap_screen_w, snap_screen_h, insets, []Rect2{},
		cfg)
	assert y == 26
	// The right edge snaps flush to the work-area right (no side insets here).
	x, _ := snap_position(snap_screen_w - 300 - 5, 400, 300, 200, snap_screen_w, snap_screen_h,
		insets, []Rect2{}, cfg)
	assert x == snap_screen_w - 300
}

// (b) With to_windows, an edge snaps flush to another window's border.
fn test_snaps_to_other_window() {
	cfg := SnapConfig{
		to_windows: true
		distance:   12
	}
	other := Rect2{
		x: 500
		y: 100
		w: 300
		h: 200
	}
	// Our left edge at 806 is 6px from the other window's right edge (800):
	// snaps our left to 800 so the borders sit flush.
	x, _ := snap_position(806, 400, 200, 150, snap_screen_w, snap_screen_h, PanelInsets{},
		[other], cfg)
	assert x == other.x + other.w // 800
}

// (c) Past the threshold, movement is free (no snap).
fn test_no_snap_past_threshold() {
	cfg := SnapConfig{
		to_edges: true
		distance: 12
	}
	// 40px from the edge: well outside the 12px threshold.
	x, y := snap_position(40, 300, 400, 200, snap_screen_w, snap_screen_h, PanelInsets{},
		[]Rect2{}, cfg)
	assert x == 40
	assert y == 300
}

// Disabled flags mean no snapping even flush against an edge.
fn test_no_snap_when_disabled() {
	cfg := SnapConfig{
		to_edges:   false
		to_windows: false
		distance:   12
	}
	x, y := snap_position(3, 3, 400, 200, snap_screen_w, snap_screen_h, PanelInsets{},
		[]Rect2{}, cfg)
	assert x == 3
	assert y == 3
}

// Zero distance disables snapping regardless of the flags.
fn test_zero_distance_is_free() {
	cfg := SnapConfig{
		to_edges: true
		distance: 0
	}
	x, _ := snap_position(2, 300, 400, 200, snap_screen_w, snap_screen_h, PanelInsets{},
		[]Rect2{}, cfg)
	assert x == 2
}
