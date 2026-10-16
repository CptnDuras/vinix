// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Shell — panel layout engine (spec E1).
//
// The generic layout math for a horizontal panel, extracted from wm.v's
// taskbar_element() so it can be reasoned about and unit-tested in isolation
// (no ui2). taskbar_element() delegates to this for item sizing/positioning;
// the element-tree assembly stays in wm.v.
//
// The first cut reproduces the current taskbar/dock behaviour exactly:
//   [ start orb ][ shared window entries ...............] [ clock (reserved) ]
// Entries share the space left between the start orb and the reserved clock
// area, shrinking to a minimum before any are dropped, and an entry that would
// overflow the reserved area is not placed.
//
// See desktop/blue-specs/shell.md.
module main

// PanelSlotLayout is the computed geometry for the run of shared "entry" items
// (the window list) inside a panel: the width each entry gets, the x of the
// first entry, and how many entries actually fit before the reserved trailing
// area (the clock).
struct PanelSlotLayout {
	item_width  int // width allocated to each visible entry
	first_x     int // x of the first entry
	visible     int // how many entries fit (others are dropped)
	entry_right int // right boundary entries may not cross (clock's left edge)
}

// PanelLayoutInput mirrors the quantities taskbar_element() uses today.
struct PanelLayoutInput {
	panel_width    int
	edge_padding   int
	start_width    int // width of the leading system-menu/start item (0 if none)
	start_gap      int // gap after the start item
	clock_width    int // reserved trailing width (0 if none)
	item_gap       int
	entry_count    int
	default_width  int // preferred per-entry width (taskbar_item_width or dock_item_width)
	min_width      int // never shrink an entry below this
}

// compute_panel_slots reproduces taskbar_element()'s space-sharing exactly:
//   x       = edge_padding + start_width + start_gap
//   right   = panel_width - edge_padding - clock_width - item_gap
//   share   = (right - x + item_gap) / n - item_gap        (n > 0)
//   width   = clamp(share <= default ? share : default, >= min)
// then place entries left to right, stopping when the next would cross `right`.
fn compute_panel_slots(inp PanelLayoutInput) PanelSlotLayout {
	first_x := inp.edge_padding + inp.start_width + inp.start_gap
	entry_right := inp.panel_width - inp.edge_padding - inp.clock_width - inp.item_gap

	mut item_width := inp.default_width
	if inp.entry_count > 0 {
		share := (entry_right - first_x + inp.item_gap) / inp.entry_count - inp.item_gap
		if share < item_width {
			item_width = share
		}
		if item_width < inp.min_width {
			item_width = inp.min_width
		}
	}

	// Count how many entries fit before crossing entry_right.
	mut x := first_x
	mut visible := 0
	for _ in 0 .. inp.entry_count {
		if x + item_width > entry_right {
			break
		}
		visible++
		x += item_width + inp.item_gap
	}

	return PanelSlotLayout{
		item_width:  item_width
		first_x:     first_x
		visible:     visible
		entry_right: entry_right
	}
}

// panel_entry_x returns the x of the i-th visible entry given the layout.
fn panel_entry_x(layout PanelSlotLayout, i int, item_gap int) int {
	return layout.first_x + i * (layout.item_width + item_gap)
}
