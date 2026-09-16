// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Window handling — window snapping (spec D5, ISSUES.md GAP-5).
//
// While a window is dragged, its leading edges snap flush to the screen edges
// (respecting reserved panel insets) and, optionally, to other windows' edges,
// once they come within `snap_distance`. Past the threshold the window moves
// freely again. The computation is pure geometry over the proposed position,
// the screen, the reserved insets and the other windows' rects, so it is
// unit-testable without ui2; wm.v feeds it the live drag position.
//
// `opaque_move_resize` (outline vs live-content drag) is a rendering choice
// carried in Behavior; it does not affect the snapped position and so is not
// part of this module.
module main

// SnapConfig is the resolved snapping policy (from EffectiveBehavior).
struct SnapConfig {
	to_edges   bool
	to_windows bool
	distance   int
}

// snap_position returns the position a window at (`x`,`y`) of size (`w`,`h`)
// should take, snapping its edges to the screen work area (screen minus panel
// insets) and to `others` when enabled and within `cfg.distance`. When nothing
// is within range, or snapping is disabled, the input position is returned
// unchanged (free movement).
//
// Each axis is considered independently: the left/right edges snap in x, the
// top/bottom edges snap in y. The nearest candidate within the threshold wins
// per axis.
fn snap_position(x int, y int, w int, h int, screen_w int, screen_h int, insets PanelInsets, others []Rect2, cfg SnapConfig) (int, int) {
	work_left := insets.left
	work_top := insets.top
	work_right := screen_w - insets.right
	work_bottom := screen_h - insets.bottom

	mut out_x := x
	mut out_y := y

	// Build the candidate edge positions for each axis. A candidate is a target
	// value for the window's own left (x) or top (y) that would place an edge
	// flush against a reference edge.
	mut x_targets := []int{}
	mut y_targets := []int{}

	if cfg.to_edges {
		// Left edge flush to the work-area left; right edge flush to the right.
		x_targets << work_left
		x_targets << work_right - w
		// Top/bottom likewise.
		y_targets << work_top
		y_targets << work_bottom - h
	}

	if cfg.to_windows {
		for o in others {
			// Align our left to their left / right; our right to their left /
			// right (so borders sit flush on either side).
			x_targets << o.x
			x_targets << o.x + o.w - w
			x_targets << o.x + o.w // our left against their right
			x_targets << o.x - w // our right against their left
			y_targets << o.y
			y_targets << o.y + o.h - h
			y_targets << o.y + o.h
			y_targets << o.y - h
		}
	}

	out_x = snap_axis(x, x_targets, cfg.distance)
	out_y = snap_axis(y, y_targets, cfg.distance)
	return out_x, out_y
}

// snap_axis returns the nearest target within `distance` of `value`, or `value`
// unchanged when none qualifies. Ties resolve to the first-seen target.
fn snap_axis(value int, targets []int, distance int) int {
	if distance <= 0 {
		return value
	}
	mut best := value
	mut best_delta := distance + 1
	for t in targets {
		delta := abs_snap(t - value)
		if delta <= distance && delta < best_delta {
			best = t
			best_delta = delta
		}
	}
	return best
}

fn abs_snap(v int) int {
	return if v < 0 { -v } else { v }
}
