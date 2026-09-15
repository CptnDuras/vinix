// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for the Blue bevel primitive (spec B2). Renders into an off-screen
// Canvas and asserts edge/interior pixels. No ui2 dependency.
module main

const c_light = u32(0xffffff)
const c_dark = u32(0x404040)
const c_bg = u32(0x808080)

fn new_test_canvas(w int, h int) Canvas {
	mut c := new_canvas(w, h)
	c.clear(c_bg)
	return c
}

@[inline]
fn (c &Canvas) at(x int, y int) u32 {
	return unsafe { c.pixels[y * c.stride + x] }
}

// raised: light top-left, dark bottom-right.
fn test_raised_edges() {
	mut c := new_test_canvas(20, 20)
	c.bevel_rect(2, 2, 10, 10, .raised, 1, c_light, c_dark, 0)
	assert c.at(2, 2) == c_light // top-left corner
	assert c.at(6, 2) == c_light // top edge
	assert c.at(2, 6) == c_light // left edge
	assert c.at(11, 11) == c_dark // bottom-right corner
	assert c.at(6, 11) == c_dark // bottom edge
	assert c.at(11, 6) == c_dark // right edge
}

// sunken is the color-inverse of raised.
fn test_sunken_is_inverse_of_raised() {
	mut r := new_test_canvas(20, 20)
	mut s := new_test_canvas(20, 20)
	r.bevel_rect(2, 2, 10, 10, .raised, 1, c_light, c_dark, 0)
	s.bevel_rect(2, 2, 10, 10, .sunken, 1, c_light, c_dark, 0)
	// Every edge pixel of sunken equals raised with light/dark swapped.
	for pt in [[2, 2], [6, 2], [2, 6], [11, 11], [6, 11], [11, 6]] {
		x, y := pt[0], pt[1]
		rp := r.at(x, y)
		sp := s.at(x, y)
		expect := if rp == c_light { c_dark } else { c_light }
		assert sp == expect
	}
}

// The interior is left untouched (callers fill it).
fn test_interior_untouched() {
	mut c := new_test_canvas(20, 20)
	c.bevel_rect(2, 2, 10, 10, .raised, 1, c_light, c_dark, 0)
	assert c.at(6, 6) == c_bg // well inside, width 1 => interior is bg
}

// flat is a no-op.
fn test_flat_is_noop() {
	mut c := new_test_canvas(20, 20)
	c.bevel_rect(2, 2, 10, 10, .flat, 1, c_light, c_dark, 0)
	for y in 0 .. 20 {
		for x in 0 .. 20 {
			assert c.at(x, y) == c_bg
		}
	}
}

// The bevel obeys the active clip: pixels outside the clip stay untouched.
fn test_respects_clip() {
	mut c := new_test_canvas(20, 20)
	saved := c.push_clip_rect(0, 0, 6, 20) // clip to left half
	c.bevel_rect(2, 2, 12, 10, .raised, 1, c_light, c_dark, 0)
	c.restore_clip(saved)
	// The right edge (x = 13) is outside the clip and must be unchanged.
	assert c.at(13, 6) == c_bg
	// The left edge (x = 2) is inside the clip and drawn.
	assert c.at(2, 6) == c_light
}

// groove draws a two-line incision: a dark then a light line inside it.
fn test_groove_two_lines() {
	mut c := new_test_canvas(20, 20)
	c.bevel_rect(2, 2, 12, 12, .groove, 1, c_light, c_dark, 0)
	assert c.at(2, 2) == c_dark // outer line top-left is dark
	assert c.at(3, 3) == c_light // inner line top-left is light
}

// zero width is a no-op.
fn test_zero_width_noop() {
	mut c := new_test_canvas(20, 20)
	c.bevel_rect(2, 2, 10, 10, .raised, 0, c_light, c_dark, 0)
	assert c.at(2, 2) == c_bg
}
