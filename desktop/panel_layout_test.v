// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for the Blue Shell panel layout engine (spec E1). Pure arithmetic, no
// ui2 — runs under base V. These lock the current taskbar space-sharing so the
// wm.v delegation is a provable no-regression.
module main

// Representative of today's taskbar constants.
const t_edge = 10
const t_start = 42
const t_start_gap = 8
const t_clock = 132
const t_gap = 6
const t_default = 168
const t_min = 84

fn base_input(width int, entries int) PanelLayoutInput {
	return PanelLayoutInput{
		panel_width:   width
		edge_padding:  t_edge
		start_width:   t_start
		start_gap:     t_start_gap
		clock_width:   t_clock
		item_gap:      t_gap
		entry_count:   entries
		default_width: t_default
		min_width:     t_min
	}
}

// First entry always begins just after the start orb + gap.
fn test_first_x_after_start() {
	l := compute_panel_slots(base_input(1280, 0))
	assert l.first_x == t_edge + t_start + t_start_gap
}

// Few entries on a wide bar keep the preferred width (share caps at default).
fn test_few_entries_use_default_width() {
	l := compute_panel_slots(base_input(1920, 2))
	assert l.item_width == t_default
	assert l.visible == 2
}

// Many entries share the space and shrink, but never below the minimum.
fn test_many_entries_shrink_to_min_floor() {
	l := compute_panel_slots(base_input(1024, 20))
	assert l.item_width == t_min
	// Not all 20 fit at the min width; the rest are dropped, never overflowing.
	assert l.visible < 20
	assert l.visible > 0
}

// No entry is placed past the reserved clock area.
fn test_entries_do_not_cross_clock() {
	l := compute_panel_slots(base_input(1024, 20))
	last_right := panel_entry_x(l, l.visible - 1, t_gap) + l.item_width
	assert last_right <= l.entry_right
	// One more would have crossed.
	next_x := panel_entry_x(l, l.visible, t_gap)
	assert next_x + l.item_width > l.entry_right
}

// Zero entries: width stays default, nothing visible, clock area preserved.
fn test_zero_entries() {
	l := compute_panel_slots(base_input(1280, 0))
	assert l.visible == 0
	assert l.item_width == t_default
	assert l.entry_right == 1280 - t_edge - t_clock - t_gap
}

// Entry x positions are evenly spaced by width + gap.
fn test_entry_positions_evenly_spaced() {
	l := compute_panel_slots(base_input(1600, 4))
	for i in 1 .. l.visible {
		gap := panel_entry_x(l, i, t_gap) - panel_entry_x(l, i - 1, t_gap)
		assert gap == l.item_width + t_gap
	}
}
