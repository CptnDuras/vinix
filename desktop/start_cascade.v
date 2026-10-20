// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// The cascading Start menus: the Deskbar menu of BeOS and the root menu of
// Fluxbox. Both are a column of rows from which submenus open to the side, so
// they share this model; what tells them apart is only the look in
// start_cascade_ui.v and the rows their roots hold.
//
// Nothing here knows about ui2 or the Desktop: a menu is a tree of
// CascadeEntry, the open submenus are a path of row indices, and the boxes'
// places are computed from sizes alone.
module main

// StartMenuStyle is which Start menu the desktop shows. follow_look takes the
// style the current look prefers, which is how a preset of the Appearance page
// can include its menu.
enum StartMenuStyle {
	follow_look
	windows
	fluxbox
	deskbar
	kmenu
}

const start_menu_style_ids = ['look', 'windows', 'fluxbox', 'deskbar', 'kmenu']

fn start_menu_style_id(style StartMenuStyle) string {
	return start_menu_style_ids[int(style)]
}

fn start_menu_style_parse(id string) ?StartMenuStyle {
	for index, known in start_menu_style_ids {
		if known == id {
			return unsafe { StartMenuStyle(index) }
		}
	}
	return none
}

// start_menu_style_resolved turns the user's choice and the look's own into the
// style that is drawn. A look never prefers follow_look.
fn start_menu_style_resolved(chosen StartMenuStyle, look StartMenuStyle) StartMenuStyle {
	if chosen != .follow_look {
		return chosen
	}
	return if look == .follow_look { StartMenuStyle.windows } else { look }
}

fn (s StartMenuStyle) cascades() bool {
	return s == .fluxbox || s == .deskbar || s == .kmenu
}

// One row of a cascading menu. A row with children opens them; a row without
// runs its action; a separator is a rule.
struct CascadeEntry {
	title     string
	action    string
	icon      string
	children  []CascadeEntry
	separator bool
	enabled   bool = true
}

fn cascade_separator() CascadeEntry {
	return CascadeEntry{
		separator: true
	}
}

fn cascade_row(title string, action string, icon string) CascadeEntry {
	return CascadeEntry{
		title: title
		action: action
		icon: icon
	}
}

fn cascade_parent(title string, icon string, children []CascadeEntry) CascadeEntry {
	return CascadeEntry{
		title: title
		icon: icon
		children: children
	}
}

// The ids of a cascading menu's rows: its depth (0 is the root) and the row.
const cascade_prefix = 'start.cas.'

fn cascade_row_id(depth int, index int) string {
	return '${cascade_prefix}${depth}.${index}'
}

// cascade_row_parse is the inverse of cascade_row_id.
fn cascade_row_parse(id string) ?(int, int) {
	if !id.starts_with(cascade_prefix) {
		return none
	}
	rest := id[cascade_prefix.len..]
	dot := rest.index('.') or { return none }
	if dot == 0 || dot == rest.len - 1 {
		return none
	}
	depth := rest[..dot]
	index := rest[dot + 1..]
	for ch in depth {
		if ch < `0` || ch > `9` {
			return none
		}
	}
	for ch in index {
		if ch < `0` || ch > `9` {
			return none
		}
	}
	return depth.int(), index.int()
}

// cascade_level is the rows shown at a depth of the open path: the root's at
// depth 0, and below it the children of the row the path took. The path is cut
// where it stops being a chain of parents.
fn cascade_level(root []CascadeEntry, path []int, depth int) []CascadeEntry {
	mut rows := unsafe { root }
	for step in 0 .. depth {
		if step >= path.len || path[step] < 0 || path[step] >= rows.len {
			return []CascadeEntry{}
		}
		rows = rows[path[step]].children
	}
	return rows
}

// cascade_path_depth is how many boxes are open: the root and a box for every
// step of the path that leads to a parent.
fn cascade_path_depth(root []CascadeEntry, path []int) int {
	mut depth := 1
	for step in 0 .. path.len {
		if cascade_level(root, path, step + 1).len == 0 {
			break
		}
		depth++
	}
	return depth
}

// cascade_hover is the path after the pointer rests on a row: its parents stay
// open, the row's own children open if it has any, and the boxes deeper than
// the row close.
fn cascade_hover(root []CascadeEntry, path []int, depth int, index int) []int {
	rows := cascade_level(root, path, depth)
	mut next := []int{cap: depth + 1}
	for step in 0 .. depth {
		if step < path.len {
			next << path[step]
		}
	}
	if index >= 0 && index < rows.len && rows[index].children.len > 0 && rows[index].enabled
		&& !rows[index].separator {
		next << index
	}
	return next
}

// cascade_find reaches the row an id names with the path as it is.
fn cascade_find(root []CascadeEntry, path []int, depth int, index int) ?CascadeEntry {
	rows := cascade_level(root, path, depth)
	if index < 0 || index >= rows.len {
		return none
	}
	return rows[index]
}

// The sizes a menu is laid out from.
struct CascadeMetrics {
	row_height       int = 24
	separator_height int = 7
	header_height    int // a title above the rows, 0 for none
	padding          int = 2
	min_width        int = 140
	max_width        int = 260
	char_width       int = 7
	icon_width       int = 24 // the icon column plus its gap, 0 for none
	arrow_width      int = 18
	// A strip down the left of the root box that holds no rows, as the K menu has.
	banner int
	// How far a submenu overlaps the row that opens it.
	overlap int = 2
}

struct CascadeRect {
	x      int
	y      int
	width  int
	height int
}

fn (r CascadeRect) contains(x int, y int) bool {
	return x >= r.x && y >= r.y && x < r.x + r.width && y < r.y + r.height
}

// cascade_column_width fits a column to its widest title, within the metrics'
// limits.
fn cascade_column_width(rows []CascadeEntry, m CascadeMetrics) int {
	mut widest := 0
	for row in rows {
		if row.separator {
			continue
		}
		mut width := row.title.len * m.char_width + m.icon_width
		if row.children.len > 0 {
			width += m.arrow_width
		}
		if width > widest {
			widest = width
		}
	}
	width := widest + 2 * m.padding + 16
	if width < m.min_width {
		return m.min_width
	}
	if width > m.max_width {
		return m.max_width
	}
	return width
}

fn cascade_row_extent(row CascadeEntry, m CascadeMetrics) int {
	return if row.separator { m.separator_height } else { m.row_height }
}

// CascadeShape is the size of one box and how its rows are divided into
// columns. A menu taller than the screen wraps into a second column, and a
// third, as Fluxbox's does, rather than running off the screen.
struct CascadeShape {
	starts       []int // the first row of each column; the first is 0
	column_width int
	width        int // every column, and the banner if this is the root
	height       int
	header       int // the title above the rows: the root's alone
	banner       int
}

fn (s CascadeShape) columns() int {
	return s.starts.len
}

// column_of is the column a row is in.
fn (s CascadeShape) column_of(index int) int {
	mut column := 0
	for i, start in s.starts {
		if index >= start {
			column = i
		}
	}
	return column
}

// cascade_shape lays a box's rows out so that no column is taller than
// max_height, unless a single row is.
fn cascade_shape(rows []CascadeEntry, depth int, m CascadeMetrics, max_height int) CascadeShape {
	header := if depth == 0 { m.header_height } else { 0 }
	banner := if depth == 0 { m.banner } else { 0 }
	chrome := header + 2 * m.padding
	mut starts := [0]
	mut used := chrome
	mut tallest := chrome
	for i, row in rows {
		extent := cascade_row_extent(row, m)
		if used + extent > max_height && used > chrome {
			// A rule at the foot of a column is wasted: leave it there and start
			// the next column with the row after.
			starts << if row.separator { i + 1 } else { i }
			used = chrome
			if row.separator {
				continue
			}
		}
		used += extent
		if used > tallest {
			tallest = used
		}
	}
	column_width := cascade_column_width(rows, m)
	return CascadeShape{
		starts: starts
		column_width: column_width
		width: column_width * starts.len + banner
		height: tallest
		header: header
		banner: banner
	}
}

// cascade_row_y is where a row starts down its box.
fn cascade_row_y(rows []CascadeEntry, shape CascadeShape, index int, m CascadeMetrics) int {
	mut top := shape.header + m.padding
	for i in shape.starts[shape.column_of(index)] .. index {
		if i >= rows.len {
			break
		}
		top += cascade_row_extent(rows[i], m)
	}
	return top
}

// cascade_row_x is where a row's column starts across its box.
fn cascade_row_x(shape CascadeShape, index int) int {
	return shape.banner + shape.column_of(index) * shape.column_width
}

// cascade_row_at is the row at a point inside a box, or -1.
fn cascade_row_at(rows []CascadeEntry, shape CascadeShape, x int, y int, m CascadeMetrics) int {
	if x < shape.banner || x >= shape.width {
		return -1
	}
	column := (x - shape.banner) / shape.column_width
	if column < 0 || column >= shape.starts.len {
		return -1
	}
	end := if column + 1 < shape.starts.len { shape.starts[column + 1] } else { rows.len }
	mut top := shape.header + m.padding
	for i in shape.starts[column] .. end {
		bottom := top + cascade_row_extent(rows[i], m)
		if y >= top && y < bottom {
			return if rows[i].separator { -1 } else { i }
		}
		top = bottom
	}
	return -1
}

// cascade_place puts the box of a submenu beside the row that opens it: to the
// right of the parent, or to its left when that would leave the screen, and as
// high as its row but never past the bottom or top of the screen.
fn cascade_place(parent CascadeRect, row_top int, width int, height int, screen_width int, screen_height int, m CascadeMetrics) CascadeRect {
	mut x := parent.x + parent.width - m.overlap
	if x + width > screen_width {
		x = parent.x - width + m.overlap
	}
	if x < 0 {
		x = 0
	}
	mut y := parent.y + row_top - m.padding
	if y + height > screen_height {
		y = screen_height - height
	}
	if y < 0 {
		y = 0
	}
	return CascadeRect{
		x: x
		y: y
		width: width
		height: height
	}
}

// cascade_shapes is the shape of every open box, the root first. The root has
// the room above the taskbar, and so has a submenu: none covers the taskbar.
fn cascade_shapes(root []CascadeEntry, path []int, anchor_bottom int, m CascadeMetrics) []CascadeShape {
	depth := cascade_path_depth(root, path)
	mut shapes := []CascadeShape{cap: depth}
	for level in 0 .. depth {
		shapes << cascade_shape(cascade_level(root, path, level), level, m, anchor_bottom)
	}
	return shapes
}

// cascade_layout is the box of every open depth, the root first. The root's
// bottom-left corner is `anchor_x`, `anchor_bottom`, where the Start button's
// edge is, and it is moved in if the screen is too small for it.
fn cascade_layout(root []CascadeEntry, path []int, anchor_x int, anchor_bottom int, screen_width int, m CascadeMetrics) []CascadeRect {
	shapes := cascade_shapes(root, path, anchor_bottom, m)
	mut root_x := anchor_x
	if root_x + shapes[0].width > screen_width {
		root_x = screen_width - shapes[0].width
	}
	if root_x < 0 {
		root_x = 0
	}
	mut root_y := anchor_bottom - shapes[0].height
	if root_y < 0 {
		root_y = 0
	}
	mut boxes := [
		CascadeRect{
			x: root_x
			y: root_y
			width: shapes[0].width
			height: shapes[0].height
		},
	]
	for level in 1 .. shapes.len {
		parent_rows := cascade_level(root, path, level - 1)
		boxes << cascade_place(boxes[level - 1], cascade_row_y(parent_rows, shapes[level - 1], path[level - 1], m),
			shapes[level].width, shapes[level].height, screen_width, anchor_bottom, m)
	}
	return boxes
}

// cascade_frame is the smallest rectangle that holds every open box, which is
// the area a click can be a click on the menu.
fn cascade_frame(boxes []CascadeRect) CascadeRect {
	if boxes.len == 0 {
		return CascadeRect{}
	}
	mut left := boxes[0].x
	mut top := boxes[0].y
	mut right := boxes[0].x + boxes[0].width
	mut bottom := boxes[0].y + boxes[0].height
	for box in boxes {
		if box.x < left {
			left = box.x
		}
		if box.y < top {
			top = box.y
		}
		if box.x + box.width > right {
			right = box.x + box.width
		}
		if box.y + box.height > bottom {
			bottom = box.y + box.height
		}
	}
	return CascadeRect{
		x: left
		y: top
		width: right - left
		height: bottom - top
	}
}
