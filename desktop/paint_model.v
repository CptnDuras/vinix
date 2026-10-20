// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// The pixel editor's document and its drawing tools (Theme Studio). A picture
// is a small grid of 0xAARRGGBB pixels; alpha 0 is transparent, which is what a
// skin's bitmap wants round a control's edge. Everything here is plain
// arithmetic on that grid, so it is tested without a window.
module main

// The biggest picture the editor makes, and how many steps it can take back.
const paint_max_side = 64
const paint_undo_limit = 40

enum PaintTool {
	pencil
	eraser
	fill
	picker
	line
	rect
	rect_filled
	ellipse
	ellipse_filled
}

// paint_tool_is_shape is whether a tool is drawn between the press and the
// release, shown as it will be while the pointer is still down.
fn paint_tool_is_shape(tool PaintTool) bool {
	return tool in [.line, .rect, .rect_filled, .ellipse, .ellipse_filled]
}

struct PaintDoc {
mut:
	width  int
	height int
	pixels []u32
	undo   [][]u32
	redo   [][]u32
}

fn new_paint_doc(width int, height int) PaintDoc {
	w := clamp_int(width, 1, paint_max_side)
	h := clamp_int(height, 1, paint_max_side)
	return PaintDoc{
		width: w
		height: h
		pixels: []u32{len: w * h}
	}
}

fn (d &PaintDoc) inside(x int, y int) bool {
	return x >= 0 && y >= 0 && x < d.width && y < d.height
}

// at is the pixel at (x, y); outside the picture it is transparent.
fn (d &PaintDoc) at(x int, y int) u32 {
	if !d.inside(x, y) {
		return 0
	}
	return d.pixels[y * d.width + x]
}

fn (mut d PaintDoc) set(x int, y int, color u32) {
	if d.inside(x, y) {
		d.pixels[y * d.width + x] = color
	}
}

// stamp paints a square brush `size` pixels across, centred as near as it can
// be on (x, y).
fn (mut d PaintDoc) stamp(x int, y int, size int, color u32) {
	s := if size < 1 { 1 } else { size }
	left := x - (s - 1) / 2
	top := y - (s - 1) / 2
	for j in 0 .. s {
		for i in 0 .. s {
			d.set(left + i, top + j, color)
		}
	}
}

// checkpoint remembers the picture so undo can come back to it. A new edit
// forgets what was undone.
fn (mut d PaintDoc) checkpoint() {
	d.undo << d.pixels.clone()
	if d.undo.len > paint_undo_limit {
		d.undo.delete(0)
	}
	d.redo.clear()
}

fn (mut d PaintDoc) undo_step() bool {
	if d.undo.len == 0 {
		return false
	}
	d.redo << d.pixels.clone()
	d.pixels = d.undo.pop()
	return true
}

fn (mut d PaintDoc) redo_step() bool {
	if d.redo.len == 0 {
		return false
	}
	d.undo << d.pixels.clone()
	d.pixels = d.redo.pop()
	return true
}

// clear empties the picture, as a step that can be taken back.
fn (mut d PaintDoc) clear() {
	d.checkpoint()
	for i in 0 .. d.pixels.len {
		d.pixels[i] = 0
	}
}

// resize gives the picture a new size, keeping what fits from its top left.
// The history goes, since its steps are the old size.
fn (mut d PaintDoc) resize(width int, height int) {
	w := clamp_int(width, 1, paint_max_side)
	h := clamp_int(height, 1, paint_max_side)
	mut next := []u32{len: w * h}
	for y in 0 .. if h < d.height { h } else { d.height } {
		for x in 0 .. if w < d.width { w } else { d.width } {
			next[y * w + x] = d.pixels[y * d.width + x]
		}
	}
	d.width = w
	d.height = h
	d.pixels = next
	d.undo.clear()
	d.redo.clear()
}

// draw_line joins two points with a straight run of brush stamps (Bresenham).
fn (mut d PaintDoc) draw_line(x0 int, y0 int, x1 int, y1 int, size int, color u32) {
	mut x := x0
	mut y := y0
	dx := if x1 > x0 { x1 - x0 } else { x0 - x1 }
	dy := if y1 > y0 { y0 - y1 } else { y1 - y0 }
	step_x := if x0 < x1 { 1 } else { -1 }
	step_y := if y0 < y1 { 1 } else { -1 }
	mut err := dx + dy
	for {
		d.stamp(x, y, size, color)
		if x == x1 && y == y1 {
			break
		}
		doubled := 2 * err
		if doubled >= dy {
			err += dy
			x += step_x
		}
		if doubled <= dx {
			err += dx
			y += step_y
		}
	}
}

// draw_rect draws the rectangle with these two corners, hollow or filled.
fn (mut d PaintDoc) draw_rect(x0 int, y0 int, x1 int, y1 int, size int, color u32, filled bool) {
	left := if x0 < x1 { x0 } else { x1 }
	right := if x0 < x1 { x1 } else { x0 }
	top := if y0 < y1 { y0 } else { y1 }
	bottom := if y0 < y1 { y1 } else { y0 }
	if filled {
		for y in top .. bottom + 1 {
			for x in left .. right + 1 {
				d.set(x, y, color)
			}
		}
		return
	}
	d.draw_line(left, top, right, top, size, color)
	d.draw_line(left, bottom, right, bottom, size, color)
	d.draw_line(left, top, left, bottom, size, color)
	d.draw_line(right, top, right, bottom, size, color)
}

// in_ellipse is whether the centre of pixel (x, y) is inside the ellipse that
// just fits the box with these corners. The integers are doubled so that an
// even-sided box has its centre between pixels.
fn in_ellipse(x int, y int, left int, top int, right int, bottom int) bool {
	w := right - left + 1
	h := bottom - top + 1
	if x < left || x > right || y < top || y > bottom {
		return false
	}
	dx := 2 * x - left - right
	dy := 2 * y - top - bottom
	return dx * dx * h * h + dy * dy * w * w <= w * w * h * h
}

// draw_ellipse draws the ellipse that fits the box with these two corners: a
// one-pixel outline, or filled.
fn (mut d PaintDoc) draw_ellipse(x0 int, y0 int, x1 int, y1 int, color u32, filled bool) {
	left := if x0 < x1 { x0 } else { x1 }
	right := if x0 < x1 { x1 } else { x0 }
	top := if y0 < y1 { y0 } else { y1 }
	bottom := if y0 < y1 { y1 } else { y0 }
	for y in top .. bottom + 1 {
		for x in left .. right + 1 {
			if !in_ellipse(x, y, left, top, right, bottom) {
				continue
			}
			edge := !in_ellipse(x - 1, y, left, top, right, bottom)
				|| !in_ellipse(x + 1, y, left, top, right, bottom)
				|| !in_ellipse(x, y - 1, left, top, right, bottom)
				|| !in_ellipse(x, y + 1, left, top, right, bottom)
			if filled || edge {
				d.set(x, y, color)
			}
		}
	}
}

// flood_fill replaces the area of one colour that (x, y) is in, reaching along
// the four directions, with `color`.
fn (mut d PaintDoc) flood_fill(x int, y int, color u32) {
	if !d.inside(x, y) {
		return
	}
	target := d.at(x, y)
	if target == color {
		return
	}
	mut stack := [[x, y]]
	for stack.len > 0 {
		point := stack.pop()
		px := point[0]
		py := point[1]
		if !d.inside(px, py) || d.at(px, py) != target {
			continue
		}
		d.set(px, py, color)
		stack << [px + 1, py]
		stack << [px - 1, py]
		stack << [px, py + 1]
		stack << [px, py - 1]
	}
}

// draw_shape draws what a shape tool makes between two corners.
fn (mut d PaintDoc) draw_shape(tool PaintTool, x0 int, y0 int, x1 int, y1 int, size int, color u32) {
	match tool {
		.line { d.draw_line(x0, y0, x1, y1, size, color) }
		.rect { d.draw_rect(x0, y0, x1, y1, size, color, false) }
		.rect_filled { d.draw_rect(x0, y0, x1, y1, size, color, true) }
		.ellipse { d.draw_ellipse(x0, y0, x1, y1, color, false) }
		.ellipse_filled { d.draw_ellipse(x0, y0, x1, y1, color, true) }
		else {}
	}
}

// PaintRun is a stretch of one colour along a row: what the editor draws, so a
// picture of a few flat colours is a few boxes rather than one a pixel.
struct PaintRun {
	x     int
	y     int
	width int
	color u32
}

// runs lists the opaque stretches of each row, left to right, top to bottom.
fn (d &PaintDoc) runs() []PaintRun {
	mut out := []PaintRun{}
	for y in 0 .. d.height {
		mut x := 0
		for x < d.width {
			color := d.at(x, y)
			if color >> 24 == 0 {
				x++
				continue
			}
			start := x
			for x < d.width && d.at(x, y) == color {
				x++
			}
			out << PaintRun{
				x: start
				y: y
				width: x - start
				color: color
			}
		}
	}
	return out
}
