// SPDX-License-Identifier: GPL-2.0-or-later
module main

fn sample_menu() []CascadeEntry {
	return [
		cascade_row('Terminal', 'start.terminal', 'builtin:terminal'),
		cascade_parent('Programs', 'builtin:folder', [
			cascade_row('Files', 'start.launch.0', ''),
			cascade_parent('More', '', [cascade_row('Clock', 'start.launch.9', '')]),
		]),
		cascade_separator(),
		cascade_row('Shut down', 'start.shutdown', ''),
	]
}

fn test_style_ids_round_trip() {
	for style in [StartMenuStyle.follow_look, .windows, .fluxbox, .deskbar] {
		assert start_menu_style_parse(start_menu_style_id(style)) or { StartMenuStyle.windows } == style
	}
	assert start_menu_style_parse('gnome') == none
	assert start_menu_style_parse('') == none
}

fn test_style_resolution() {
	assert start_menu_style_resolved(.follow_look, .deskbar) == .deskbar
	assert start_menu_style_resolved(.fluxbox, .deskbar) == .fluxbox
	assert start_menu_style_resolved(.follow_look, .follow_look) == .windows
	assert StartMenuStyle.deskbar.cascades() && StartMenuStyle.fluxbox.cascades()
	assert !StartMenuStyle.windows.cascades() && !StartMenuStyle.follow_look.cascades()
}

fn test_row_ids_parse_back() {
	assert cascade_row_id(2, 11) == 'start.cas.2.11'
	depth, index := cascade_row_parse('start.cas.2.11') or { -1, -1 }
	assert depth == 2 && index == 11
	assert cascade_row_parse('start.cas.2') == none
	assert cascade_row_parse('start.cas..3') == none
	assert cascade_row_parse('start.cas.a.3') == none
	assert cascade_row_parse('start.cas.1.') == none
	assert cascade_row_parse('start.launch.3') == none
}

fn test_levels_follow_the_path() {
	menu := sample_menu()
	assert cascade_level(menu, [], 0).len == 4
	assert cascade_level(menu, [1], 1).len == 2
	assert cascade_level(menu, [1, 1], 2).len == 1
	// A path that leaves the tree opens nothing.
	assert cascade_level(menu, [0], 1).len == 0
	assert cascade_level(menu, [9], 1).len == 0
	assert cascade_level(menu, [1], 2).len == 0
	assert cascade_path_depth(menu, []) == 1
	assert cascade_path_depth(menu, [1]) == 2
	assert cascade_path_depth(menu, [1, 1]) == 3
	assert cascade_path_depth(menu, [0]) == 1
}

fn test_hover_opens_and_closes_boxes() {
	menu := sample_menu()
	// Resting on a parent opens it.
	assert cascade_hover(menu, [], 0, 1) == [1]
	// Moving on to a plain row closes it.
	assert cascade_hover(menu, [1], 0, 0) == []int{}
	// Resting on a deeper parent keeps its own parent open.
	assert cascade_hover(menu, [1], 1, 1) == [1, 1]
	// A plain row in the submenu closes the boxes below it and keeps the one it is in.
	assert cascade_hover(menu, [1, 1], 1, 0) == [1]
	// A separator, or no row, opens nothing.
	assert cascade_hover(menu, [1], 0, 2) == []int{}
	assert cascade_hover(menu, [1], 0, -1) == []int{}
}

fn test_a_disabled_parent_stays_shut() {
	menu := [
		CascadeEntry{
			title: 'Recent'
			enabled: false
			children: [cascade_row('x', 'a', '')]
		},
	]
	assert cascade_hover(menu, [], 0, 0) == []int{}
}

fn test_find_a_row() {
	menu := sample_menu()
	row := cascade_find(menu, [1], 1, 0) or { CascadeEntry{} }
	assert row.action == 'start.launch.0'
	assert cascade_find(menu, [1], 1, 5) == none
	assert cascade_find(menu, [], 0, -1) == none
}

fn test_box_sizes_follow_the_rows() {
	m := CascadeMetrics{
		header_height: 20
	}
	menu := sample_menu()
	root := cascade_shape(menu, 0, m, 1000)
	// header + padding*2 + three rows + one rule
	assert root.height == 20 + 4 + 3 * 24 + 7
	assert root.columns() == 1
	assert cascade_row_y(menu, root, 0, m) == 22
	assert cascade_row_y(menu, root, 2, m) == 22 + 48
	assert cascade_row_x(root, 0) == 0
	// The title is the root's alone.
	sub := cascade_shape(menu, 1, m, 1000)
	assert sub.header == 0 && sub.height == root.height - 20
	assert cascade_row_y(menu, sub, 0, m) == 2
}

fn test_a_point_finds_its_row() {
	m := CascadeMetrics{
		header_height: 20
	}
	menu := sample_menu()
	shape := cascade_shape(menu, 0, m, 1000)
	assert cascade_row_at(menu, shape, 10, 23, m) == 0
	assert cascade_row_at(menu, shape, 10, 22 + 24, m) == 1
	// The rule is no row, nor is the title, nor the world outside.
	assert cascade_row_at(menu, shape, 10, 22 + 48 + 2, m) == -1
	assert cascade_row_at(menu, shape, 10, 1, m) == -1
	assert cascade_row_at(menu, shape, 10, 5000, m) == -1
	assert cascade_row_at(menu, shape, shape.width + 5, 30, m) == -1
	assert cascade_row_at(menu, shape, -3, 30, m) == -1
}

fn test_width_fits_the_longest_title_within_limits() {
	m := CascadeMetrics{}
	short := [cascade_row('A', 'a', '')]
	assert cascade_column_width(short, m) == m.min_width
	long := [cascade_row('A very long title indeed that cannot fit anywhere sensible', 'a', '')]
	assert cascade_column_width(long, m) == m.max_width
	mid := [cascade_row('Activity Monitor tools', 'a', '')]
	assert cascade_column_width(mid, m) > m.min_width && cascade_column_width(mid, m) < m.max_width
	// A submenu arrow takes room too.
	parent := [cascade_parent('Activity Monitor tools', '', [cascade_row('x', 'a', '')])]
	assert cascade_column_width(parent, m) > cascade_column_width(mid, m)
}

fn many_rows(count int) []CascadeEntry {
	mut rows := []CascadeEntry{}
	for i in 0 .. count {
		rows << cascade_row('Program ${i}', 'start.launch.${i}', '')
	}
	return rows
}

fn test_a_tall_menu_wraps_into_columns() {
	m := CascadeMetrics{}
	rows := many_rows(40)
	// 4 padding + n * 24 <= 300 holds 12 rows a column: 4 columns for 40 rows.
	shape := cascade_shape(rows, 1, m, 300)
	assert shape.columns() == 4
	assert shape.starts == [0, 12, 24, 36]
	assert shape.height <= 300
	assert shape.width == 4 * shape.column_width
	// A row's place is its column's, and the rows of a column stack.
	assert shape.column_of(0) == 0 && shape.column_of(11) == 0 && shape.column_of(12) == 1
	assert shape.column_of(39) == 3
	assert cascade_row_x(shape, 13) == shape.column_width
	assert cascade_row_y(rows, shape, 12, m) == cascade_row_y(rows, shape, 0, m)
	assert cascade_row_y(rows, shape, 13, m) == cascade_row_y(rows, shape, 0, m) + 24
	// Every row can be found where it is drawn.
	for i in 0 .. rows.len {
		assert cascade_row_at(rows, shape, cascade_row_x(shape, i) + 5, cascade_row_y(rows, shape, i, m) + 5, m) == i
	}
}

fn test_a_menu_that_fits_stays_in_one_column() {
	shape := cascade_shape(many_rows(5), 1, CascadeMetrics{}, 800)
	assert shape.columns() == 1 && shape.starts == [0]
}

fn test_a_screen_too_small_for_a_row_still_shows_every_row() {
	rows := many_rows(3)
	shape := cascade_shape(rows, 1, CascadeMetrics{}, 10)
	// One row a column; none is lost.
	assert shape.columns() == 3
	assert shape.starts == [0, 1, 2]
}

fn test_a_rule_is_not_left_at_the_foot_of_a_column() {
	m := CascadeMetrics{}
	mut rows := many_rows(11)
	rows << cascade_separator()
	rows << cascade_row('Last', 'a', '')
	// 11 rows fill 4 + 11*24 = 268; the rule would make 275 > 280 no, so it fits
	// at 280; make it not fit.
	shape := cascade_shape(rows, 1, m, 272)
	assert shape.columns() == 2
	assert shape.starts == [0, 12]
	assert cascade_row_at(rows, shape, cascade_row_x(shape, 12) + 5, cascade_row_y(rows, shape, 12, m) + 5, m) == 12
}

fn test_submenu_goes_right_then_left() {
	m := CascadeMetrics{}
	parent := CascadeRect{
		x: 10
		y: 300
		width: 150
		height: 200
	}
	right := cascade_place(parent, 50, 140, 100, 1000, 800, m)
	assert right.x == 10 + 150 - m.overlap
	assert right.y == 300 + 50 - m.padding
	far := CascadeRect{
		x: 200
		y: 300
		width: 150
		height: 200
	}
	left := cascade_place(far, 50, 140, 100, 400, 800, m)
	assert left.x == 200 - 140 + m.overlap
	// With no room on either side it is still on the screen.
	narrow := cascade_place(CascadeRect{
		x: 0
		y: 0
		width: 150
		height: 50
	}, 0, 140, 50, 160, 800, m)
	assert narrow.x == 0
}

fn test_submenu_stays_above_the_screen_bottom() {
	m := CascadeMetrics{}
	parent := CascadeRect{
		x: 0
		y: 500
		width: 150
		height: 200
	}
	box := cascade_place(parent, 180, 140, 300, 1000, 720, m)
	assert box.y + box.height == 720
	tall := cascade_place(parent, 0, 140, 900, 1000, 720, m)
	assert tall.y == 0
}

fn test_layout_stacks_boxes_from_the_start_button() {
	m := CascadeMetrics{}
	menu := sample_menu()
	boxes := cascade_layout(menu, [1, 1], 4, 740, 1024, m)
	assert boxes.len == 3
	assert boxes[0].x == 4 && boxes[0].y + boxes[0].height == 740
	assert boxes[1].x == boxes[0].x + boxes[0].width - m.overlap
	assert boxes[2].x == boxes[1].x + boxes[1].width - m.overlap
	// The second box starts level with the row that opened it.
	root := cascade_shape(menu, 0, m, 740)
	assert boxes[1].y == boxes[0].y + cascade_row_y(menu, root, 1, m) - m.padding
	frame := cascade_frame(boxes)
	for box in boxes {
		assert frame.contains(box.x, box.y) && frame.contains(box.x + box.width - 1, box.y + box.height - 1)
	}
}

fn test_layout_pulls_the_root_onto_a_small_screen() {
	m := CascadeMetrics{}
	menu := sample_menu()
	boxes := cascade_layout(menu, [], 300, 740, 320, m)
	assert boxes[0].x + boxes[0].width <= 320
	short := cascade_layout(menu, [], 0, 40, 320, m)
	// Too little room above the button wraps the root into columns instead.
	assert short[0].y >= 0 && short[0].y + short[0].height <= 40
}

fn test_a_long_submenu_stays_on_a_small_screen() {
	m := CascadeMetrics{}
	menu := [
		cascade_parent('Programs', '', many_rows(60)),
		cascade_row('Shut down', 'start.shutdown', ''),
	]
	for screen in [[640, 480], [1024, 768], [320, 240]] {
		boxes := cascade_layout(menu, [0], 0, screen[1] - 30, screen[0], m)
		assert boxes.len == 2
		for box in boxes {
			assert box.x >= 0 && box.y >= 0
			assert box.x + box.width <= screen[0] || box.width > screen[0]
			// Above the taskbar, which is 30 px of it.
			assert box.y + box.height <= screen[1] - 30
		}
	}
}

fn test_frame_of_nothing_is_empty() {
	frame := cascade_frame([])
	assert frame.width == 0 && frame.height == 0
}

fn test_the_banner_widens_only_the_root() {
	m := CascadeMetrics{
		banner: 22
	}
	menu := sample_menu()
	root := cascade_shape(menu, 0, m, 1000)
	sub := cascade_shape(menu, 1, m, 1000)
	assert root.width == root.column_width + 22 && sub.width == sub.column_width
	assert cascade_row_x(root, 0) == 22
	assert cascade_row_at(menu, root, 5, 5, m) == -1
	assert cascade_row_at(menu, root, 22 + 5, 5, m) == 0
	boxes := cascade_layout(menu, [1], 0, 700, 1024, m)
	assert boxes[0].width == root.width
}

fn test_the_k_menu_is_a_cascading_style() {
	assert StartMenuStyle.kmenu.cascades()
	assert start_menu_style_parse('kmenu') or { StartMenuStyle.windows } == .kmenu
	assert start_menu_style_resolved(.follow_look, .kmenu) == .kmenu
}
