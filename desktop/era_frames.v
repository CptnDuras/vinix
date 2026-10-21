// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Period window frames for flat looks: the thick grey frame of Windows 3.1 and
// the striped, bevelled bar of Mac OS Platinum. A box style cannot say either
// (no borders, one gradient), so like Luna's they are drawn here, from the
// look's own colours. What the controls look like is a skin's business.
module main

import ui2

// The notches Windows 3.1 cuts across its frame, in from each corner.
const win31_notch = 20

// element_window_maximized reports whether the window an element id belongs to
// ("win.3" or "win.3.titlebar") is maximized, whose frame is off the screen.
fn (d &Desktop) element_window_maximized(id string) bool {
	if !id.starts_with('win.') {
		return false
	}
	rest := id[4..]
	end := rest.index('.') or { rest.len }
	index := d.window_index(rest[..end].int()) or { return false }
	return d.windows[index].maximized
}

// draw_era_frame paints the left, right and bottom of a window's border. The
// bar paints the top, being the part that has to know about the title.
fn (mut d Desktop) draw_era_frame(theme Theme, x int, y int, w int, h int) {
	b := theme.frame_border
	if b < 2 || w < 2 * b + 2 || h < b + theme.title_height {
		return
	}
	if theme.frame_style == .bevel {
		d.draw_bevel_ring(theme, x, y, w, h, true)
		return
	}
	// The face first, under the body that covers its middle.
	d.canvas.fill_rect(x, y, w, h, theme.frame_face)
	d.canvas.fill_rect(x, y, w, 1, theme.window_edge)
	d.canvas.fill_rect(x, y + h - 1, w, 1, theme.window_edge)
	d.canvas.fill_rect(x, y, 1, h, theme.window_edge)
	d.canvas.fill_rect(x + w - 1, y, 1, h, theme.window_edge)
	// Light along the outside of the top and left, shadow on the bottom and right.
	d.canvas.fill_rect(x + 1, y + 1, 1, h - 2, theme.frame_light)
	d.canvas.fill_rect(x + 1, y + h - 2, w - 2, 1, theme.frame_dark)
	d.canvas.fill_rect(x + w - 2, y + 1, 1, h - 2, theme.frame_dark)
	if theme.frame_style == .win31 {
		// A black rule round the body, and the notches where a corner begins.
		top := y + theme.title_height
		d.canvas.fill_rect(x + b - 1, top - 1, 1, h - theme.title_height - b + 2, theme.window_edge)
		d.canvas.fill_rect(x + w - b, top - 1, 1, h - theme.title_height - b + 2, theme.window_edge)
		d.canvas.fill_rect(x + b - 1, y + h - b, w - 2 * b + 2, 1, theme.window_edge)
		if h > theme.title_height + 2 * win31_notch && w > 4 * win31_notch {
			d.canvas.fill_rect(x, top + win31_notch, b, 1, theme.window_edge)
			d.canvas.fill_rect(x + w - b, top + win31_notch, b, 1, theme.window_edge)
			d.canvas.fill_rect(x, y + h - win31_notch, b, 1, theme.window_edge)
			d.canvas.fill_rect(x + w - b, y + h - win31_notch, b, 1, theme.window_edge)
			d.canvas.fill_rect(x + win31_notch, y + h - b, 1, b, theme.window_edge)
			d.canvas.fill_rect(x + w - win31_notch, y + h - b, 1, b, theme.window_edge)
		}
	}
}

// draw_bevel_ring paints a raised frame over a rectangle: the face, light along
// the top and left and shadow along the bottom and right. A frame two pixels
// wide has one edge (light, then the outline); a wider one has two (the face
// and the light inside it, the shadow and the outline beyond). `bottom` is
// false for a bar, which leaves the window's bottom edge to the frame.
fn (mut d Desktop) draw_bevel_ring(theme Theme, x int, y int, w int, h int, bottom bool) {
	d.canvas.fill_rect(x, y, w, h, theme.frame_face)
	outer_light := if theme.frame_border >= 3 { theme.frame_face } else { theme.frame_light }
	d.canvas.fill_rect(x, y, w, 1, outer_light)
	d.canvas.fill_rect(x, y, 1, h, outer_light)
	d.canvas.fill_rect(x + w - 1, y, 1, h, theme.window_edge)
	if bottom {
		d.canvas.fill_rect(x, y + h - 1, w, 1, theme.window_edge)
	}
	if theme.frame_border >= 3 {
		d.canvas.fill_rect(x + 1, y + 1, w - 2, 1, theme.frame_light)
		d.canvas.fill_rect(x + 1, y + 1, 1, h - 2, theme.frame_light)
		d.canvas.fill_rect(x + w - 2, y + 1, 1, h - 2, theme.frame_dark)
		if bottom {
			d.canvas.fill_rect(x + 1, y + h - 2, w - 2, 1, theme.frame_dark)
		}
	}
}

// fade paints a bar's colours: down, or across when the look fades that way.
fn (mut d Desktop) fade(theme Theme, x int, y int, w int, h int, first u32, second u32) {
	if first == second {
		d.canvas.fill_rect(x, y, w, h, first)
	} else if theme.title_across {
		d.canvas.horizontal_gradient(x, y, w, h, first, second)
	} else {
		d.canvas.vertical_gradient(x, y, w, h, first, second)
	}
}

// draw_era_bar paints a window's bar in the look's frame style, and says
// whether it did. `bar` is the bar's element: its title and controls are what
// the stripes leave room round.
fn (mut d Desktop) draw_era_bar(bar &ui2.Element, theme Theme, active bool, x int, y int, w int, h int) bool {
	if theme.frame_style == .none_ || w < 8 || h < 6 {
		return false
	}
	maximized := d.element_window_maximized(bar.id)
	top := if active { theme.title_active_bg } else { theme.title_inactive_bg }
	bottom := if active { theme.title_active_bg2 } else { theme.title_inactive_bg2 }
	match theme.frame_style {
		.win31 {
			b := if maximized { 0 } else { theme.frame_border }
			if b > 0 {
				d.canvas.fill_rect(x, y, w, h, theme.frame_face)
				d.canvas.fill_rect(x, y, w, 1, theme.window_edge)
				d.canvas.fill_rect(x, y, 1, h, theme.window_edge)
				d.canvas.fill_rect(x + w - 1, y, 1, h, theme.window_edge)
				d.canvas.fill_rect(x + 1, y + 1, w - 3, 1, theme.frame_light)
				d.canvas.fill_rect(x + 1, y + 1, 1, h - 1, theme.frame_light)
				d.canvas.fill_rect(x + w - 2, y + 1, 1, h - 1, theme.frame_dark)
				// The black rule round the caption.
				d.canvas.fill_rect(x + b - 1, y + b - 1, w - 2 * b + 2, 1, theme.window_edge)
				d.canvas.fill_rect(x + b - 1, y + b - 1, 1, h - b + 1, theme.window_edge)
				d.canvas.fill_rect(x + w - b, y + b - 1, 1, h - b + 1, theme.window_edge)
			}
			d.canvas.fill_rect(x + b, y + b, w - 2 * b, h - b, top)
		}
		.bevel {
			if maximized {
				d.fade(theme, x, y, w, h, top, bottom)
			} else {
				b := theme.frame_border
				d.draw_bevel_ring(theme, x, y, w, h, false)
				d.fade(theme, x + b, y + b, w - 2 * b, h - b, top, bottom)
			}
		}
		.platinum {
			d.canvas.fill_rect(x, y, w, h, theme.window_edge)
			inner_x := x + 1
			inner_y := y + 1
			inner_w := w - 2
			inner_h := h - 1
			if bottom != top {
				d.canvas.vertical_gradient(inner_x, inner_y, inner_w, inner_h, top, bottom)
			} else {
				d.canvas.fill_rect(inner_x, inner_y, inner_w, inner_h, top)
			}
			if active && theme.title_stripes != 0 {
				d.draw_platinum_stripes(bar, theme, x, y, w, h)
			}
			d.canvas.fill_rect(inner_x, inner_y, inner_w, 1, theme.frame_light)
			d.canvas.fill_rect(inner_x, inner_y, 1, inner_h, theme.frame_light)
			d.canvas.fill_rect(x + w - 2, inner_y, 1, inner_h, theme.frame_dark)
		}
		.none_ {}
	}
	return true
}

// draw_platinum_stripes rules the bar with a line every other row and leaves the
// bar's own colour round the title and each control, as the original does.
fn (mut d Desktop) draw_platinum_stripes(bar &ui2.Element, theme Theme, x int, y int, w int, h int) {
	left := x + 4
	right := x + w - 4
	rows_top := y + 3
	rows_bottom := y + h - 3
	if right <= left || rows_bottom <= rows_top {
		return
	}
	stripe := theme.title_stripes
	mut row := rows_top
	for row < rows_bottom {
		d.canvas.fill_rect(left, row, right - left, 1, stripe)
		row += 2
	}
	top := theme.title_active_bg
	bottom := theme.title_active_bg2
	for child in bar.children {
		mut span_x := 0
		mut span_w := 0
		if child.id.ends_with('.title') {
			if child.text.len == 0 || d.fonts.len == 0 {
				continue
			}
			face := d.face_for(child.text_style)
			text_width := face.text_width(child.text)
			span_w = text_width + 16
			span_x = x + int(child.frame.x) + (int(child.frame.width) - text_width) / 2 - 8
		} else if widget_part(child.id) != none {
			span_x = x + int(child.frame.x) - 4
			span_w = int(child.frame.width) + 8
		} else {
			continue
		}
		clipped_left := if span_x < left { left } else { span_x }
		clipped_right := if span_x + span_w > right { right } else { span_x + span_w }
		if clipped_right > clipped_left {
			if bottom != top {
				d.canvas.vertical_gradient(clipped_left, y + 1, clipped_right - clipped_left, h - 1, top,
					bottom)
			} else {
				d.canvas.fill_rect(clipped_left, y + 1, clipped_right - clipped_left, h - 1, top)
			}
		}
	}
}
