module main

const paint_red = u32(0xffff0000)
const paint_blue = u32(0xff0000ff)

fn test_a_new_picture_is_transparent_and_its_size_is_bounded() {
	d := new_paint_doc(8, 6)
	assert d.width == 8
	assert d.height == 6
	assert d.at(3, 3) == 0
	big := new_paint_doc(500, 0)
	assert big.width == paint_max_side
	assert big.height == 1
}

fn test_the_pencil_stamps_a_square_brush_and_stays_inside() {
	mut d := new_paint_doc(8, 8)
	d.stamp(0, 0, 3, paint_red)
	assert d.at(0, 0) == paint_red
	assert d.at(1, 1) == paint_red
	assert d.at(2, 2) == 0
	// A brush off the edge leaves the picture alone rather than failing.
	d.stamp(-5, -5, 2, paint_red)
	d.stamp(20, 20, 2, paint_red)
}

fn test_a_line_reaches_both_ends_in_every_direction() {
	mut d := new_paint_doc(10, 10)
	d.draw_line(1, 1, 8, 4, 1, paint_red)
	assert d.at(1, 1) == paint_red
	assert d.at(8, 4) == paint_red
	mut back := new_paint_doc(10, 10)
	back.draw_line(8, 4, 1, 1, 1, paint_red)
	assert back.at(1, 1) == paint_red
	assert back.at(8, 4) == paint_red
	mut steep := new_paint_doc(10, 10)
	steep.draw_line(2, 0, 3, 9, 1, paint_red)
	mut count := 0
	for y in 0 .. 10 {
		for x in 0 .. 10 {
			if steep.at(x, y) == paint_red {
				count++
			}
		}
	}
	// One pixel per row for a steep line.
	assert count == 10
}

fn test_a_rectangle_is_an_outline_or_filled() {
	mut hollow := new_paint_doc(10, 10)
	hollow.draw_rect(2, 2, 6, 5, 1, paint_red, false)
	assert hollow.at(2, 2) == paint_red
	assert hollow.at(6, 5) == paint_red
	assert hollow.at(4, 3) == 0
	mut solid := new_paint_doc(10, 10)
	solid.draw_rect(6, 5, 2, 2, 1, paint_red, true)
	assert solid.at(4, 3) == paint_red
	assert solid.at(7, 3) == 0
}

fn test_an_ellipse_fits_its_box() {
	mut d := new_paint_doc(12, 12)
	d.draw_ellipse(1, 1, 10, 8, paint_red, false)
	// The four extremes of the box are touched, the corners are not, and a
	// hollow one has an empty middle.
	assert d.at(1, 4) == paint_red || d.at(1, 5) == paint_red
	assert d.at(10, 4) == paint_red || d.at(10, 5) == paint_red
	assert d.at(5, 1) == paint_red || d.at(6, 1) == paint_red
	assert d.at(1, 1) == 0
	assert d.at(5, 4) == 0
	mut filled := new_paint_doc(12, 12)
	filled.draw_ellipse(1, 1, 10, 8, paint_red, true)
	assert filled.at(5, 4) == paint_red
	assert filled.at(1, 1) == 0
}

fn test_a_fill_stops_at_a_different_colour() {
	mut d := new_paint_doc(6, 6)
	d.draw_rect(1, 1, 4, 4, 1, paint_red, false)
	d.flood_fill(2, 2, paint_blue)
	assert d.at(2, 2) == paint_blue
	assert d.at(3, 3) == paint_blue
	// The wall and everything outside it are as they were.
	assert d.at(1, 1) == paint_red
	assert d.at(0, 0) == 0
	// Filling with the colour already there is a no-op, not an endless loop.
	d.flood_fill(2, 2, paint_blue)
	assert d.at(2, 2) == paint_blue
}

fn test_undo_and_redo_walk_back_and_forward() {
	mut d := new_paint_doc(4, 4)
	d.checkpoint()
	d.set(1, 1, paint_red)
	d.checkpoint()
	d.set(2, 2, paint_blue)
	assert d.undo_step()
	assert d.at(2, 2) == 0
	assert d.at(1, 1) == paint_red
	assert d.undo_step()
	assert d.at(1, 1) == 0
	assert !d.undo_step()
	assert d.redo_step()
	assert d.at(1, 1) == paint_red
	// A new edit forgets what was undone.
	d.checkpoint()
	assert !d.redo_step()
}

fn test_history_is_bounded() {
	mut d := new_paint_doc(2, 2)
	for _ in 0 .. paint_undo_limit + 10 {
		d.checkpoint()
	}
	assert d.undo.len == paint_undo_limit
}

fn test_resizing_keeps_the_top_left() {
	mut d := new_paint_doc(4, 4)
	d.set(1, 1, paint_red)
	d.set(3, 3, paint_blue)
	d.resize(6, 2)
	assert d.width == 6
	assert d.height == 2
	assert d.at(1, 1) == paint_red
	assert d.at(3, 3) == 0
	assert d.undo.len == 0
}

fn test_runs_merge_a_row_of_one_colour_and_skip_the_transparent() {
	mut d := new_paint_doc(6, 2)
	d.draw_rect(1, 0, 3, 0, 1, paint_red, true)
	d.set(5, 0, paint_blue)
	runs := d.runs()
	assert runs.len == 2
	assert runs[0].x == 1
	assert runs[0].width == 3
	assert runs[0].color == paint_red
	assert runs[1].x == 5
	assert runs[1].width == 1
}
