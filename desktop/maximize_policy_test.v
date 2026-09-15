// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for maximize policy (spec D2). Pure geometry, no ui2.
module main

// (a) fill_screen with only a bottom taskbar reproduces today's maximize when
// respect_panels is used with just the bottom inset; fill_screen ignores it.
fn test_fill_screen_uses_whole_screen() {
	r := maximize_rect(1280, 800, PanelInsets{ bottom: 46 }, .fill_screen)
	assert r == Rect2{0, 0, 1280, 800}
}

// (b) respect_panels subtracts each occupied edge (top + bottom).
fn test_respect_panels_subtracts_both_bars() {
	r := maximize_rect(1280, 800, PanelInsets{ top: 30, bottom: 46 }, .respect_panels)
	assert r.x == 0
	assert r.y == 30
	assert r.w == 1280
	assert r.h == 800 - 30 - 46
}

// Today's behaviour: only a bottom taskbar, respect_panels -> full width,
// height minus the taskbar.
fn test_respect_panels_bottom_only_matches_today() {
	taskbar := 46
	r := maximize_rect(1280, 800, PanelInsets{ bottom: taskbar }, .respect_panels)
	assert r.y == 0
	assert r.h == 800 - taskbar
	assert r.w == 1280
}

// Left/right insets (a vertical dock) are subtracted too.
fn test_respect_panels_side_insets() {
	r := maximize_rect(1280, 800, PanelInsets{ left: 60 }, .respect_panels)
	assert r.x == 60
	assert r.w == 1280 - 60
}

// Degenerate: insets larger than the screen clamp to zero, never negative.
fn test_insets_clamp_nonnegative() {
	r := maximize_rect(100, 100, PanelInsets{ top: 80, bottom: 80 }, .respect_panels)
	assert r.h == 0
}
