// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Theme Studio: a pixel editor in the manner of the original Paint, and a page
// that turns the pictures it makes into a window-control skin. The drawing is
// paint_model.v, the skin studio_skin.v; this file is the window around them.
//
// A picture is shown as one box per run of a colour in each row, so a small
// picture of a few flat colours is a few boxes, and the application's tree stays
// well inside the protocol's limits even for the biggest picture.
module main

import os
import ui2

const studio_tab_paint = 0
const studio_tab_skin = 1

const studio_tool_ids = ['studio.tool.0', 'studio.tool.1', 'studio.tool.2', 'studio.tool.3',
	'studio.tool.4', 'studio.tool.5', 'studio.tool.6', 'studio.tool.7', 'studio.tool.8']!
const studio_tool_keys = ['studio.tool.pencil', 'studio.tool.eraser', 'studio.tool.fill',
	'studio.tool.picker', 'studio.tool.line', 'studio.tool.rect', 'studio.tool.rect_filled',
	'studio.tool.ellipse', 'studio.tool.ellipse_filled']!
const studio_tools = [PaintTool.pencil, PaintTool.eraser, PaintTool.fill, PaintTool.picker,
	PaintTool.line, PaintTool.rect, PaintTool.rect_filled, PaintTool.ellipse,
	PaintTool.ellipse_filled]!
const studio_brush_ids = ['studio.brush.0', 'studio.brush.1', 'studio.brush.2', 'studio.brush.3']!
const studio_brush_sizes = [1, 2, 3, 4]!
const studio_size_ids = ['studio.size.0', 'studio.size.1', 'studio.size.2', 'studio.size.3',
	'studio.size.4']!
const studio_sizes = [10, 16, 24, 32, 48]!
const studio_pal_ids = ['studio.pal.0', 'studio.pal.1', 'studio.pal.2', 'studio.pal.3',
	'studio.pal.4', 'studio.pal.5', 'studio.pal.6', 'studio.pal.7', 'studio.pal.8', 'studio.pal.9',
	'studio.pal.10', 'studio.pal.11', 'studio.pal.12', 'studio.pal.13', 'studio.pal.14',
	'studio.pal.15', 'studio.pal.16', 'studio.pal.17', 'studio.pal.18', 'studio.pal.19',
	'studio.pal.20', 'studio.pal.21', 'studio.pal.22', 'studio.pal.23', 'studio.pal.24',
	'studio.pal.25', 'studio.pal.26', 'studio.pal.27', 'studio.pal.28']!
// The classic two rows of fourteen, then a swatch for nothing at all.
const studio_palette = [u32(0xff000000), 0xff808080, 0xff800000, 0xff808000, 0xff008000, 0xff008080,
	0xff000080, 0xff800080, 0xff808040, 0xff004040, 0xff0080ff, 0xff004080, 0xff8000ff, 0xff804000,
	0xffffffff, 0xffc0c0c0, 0xffff0000, 0xffffff00, 0xff00ff00, 0xff00ffff, 0xff0000ff, 0xffff00ff,
	0xffffff80, 0xff00ff80, 0xff80ffff, 0xff8080ff, 0xffff0080, 0xffff8040, 0]!
const studio_plate_ids = ['studio.plate.0', 'studio.plate.1', 'studio.plate.2']!
const studio_plate_keys = ['studio.plate.none', 'studio.plate.grey', 'studio.plate.shaded']!
const studio_use_ids = ['studio.use.0', 'studio.use.1', 'studio.use.2', 'studio.use.3',
	'studio.use.4']!
const studio_edit_ids = ['studio.edit.0', 'studio.edit.1', 'studio.edit.2', 'studio.edit.3',
	'studio.edit.4']!
const studio_remove_ids = ['studio.remove.0', 'studio.remove.1', 'studio.remove.2',
	'studio.remove.3', 'studio.remove.4']!
const studio_widget_keys = ['settings.windows.action.close', 'settings.windows.action.minimize',
	'settings.windows.action.maximize', 'settings.windows.action.shade',
	'settings.windows.action.menu']!

// Where the picture sits: a square of this many pixels, in the window's body.
const studio_canvas_x = 100
const studio_canvas_y = 52
const studio_canvas_span = 440
const studio_grid_color = u32(0xb4bac6)
const studio_ground = u32(0xdcdfe6)

enum StudioField {
	none_
	skin_id
	file
	colour
	skin_name
}

@[heap]
struct StudioApp {
mut:
	initialized bool
	tab         int
	doc         PaintDoc
	tool        PaintTool
	brush       int = 1
	colour      u32 = 0xff000000
	grid        bool = true
	drawing     bool
	start_x     int
	start_y     int
	last_x      int
	last_y      int
	base        []u32
	skin        StudioSkin
	previews    [5]PaintDoc
	focus       StudioField
	selected    bool
	id_input    []u8
	file_input  []u8
	hex_input   []u8
	name_input  []u8
	status      string = 'studio.ready'
	detail      string
}

fn open_studio_app(mut _ Desktop) !NativeApp {
	return &StudioApp{}
}

fn (mut app StudioApp) initialize() {
	if app.initialized {
		return
	}
	app.doc = new_paint_doc(16, 16)
	for i in 0 .. 5 {
		app.previews[i] = new_paint_doc(1, 1)
	}
	app.id_input = studio_bytes('my-skin')
	app.file_input = studio_bytes('close')
	app.hex_input = studio_bytes('#000000')
	app.name_input = studio_bytes('My skin')
	app.sync_skin_fields()
	app.initialized = true
}

fn studio_bytes(text string) []u8 {
	mut out := []u8{cap: 64}
	unsafe {
		out.flags |= .noslices
	}
	for byte in text.bytes() {
		out << byte
	}
	return out
}

// sync_skin_fields copies what is typed into the skin being made.
fn (mut app StudioApp) sync_skin_fields() {
	app.skin.id = editor_bytes_text(app.id_input).clone()
	app.skin.name = editor_bytes_text(app.name_input).clone()
}

// ── Geometry ───────────────────────────────────────────────────────

// cell is how many screen pixels one picture pixel takes.
fn (app &StudioApp) cell() int {
	longest := if app.doc.width > app.doc.height { app.doc.width } else { app.doc.height }
	return clamp_int(studio_canvas_span / longest, 2, 24)
}

fn (app &StudioApp) canvas_origin() (int, int) {
	cell := app.cell()
	return studio_canvas_x + (studio_canvas_span - app.doc.width * cell) / 2,
		studio_canvas_y + (studio_canvas_span - app.doc.height * cell) / 2
}

// pixel_at is the picture pixel under a point of the body, which may lie
// outside the picture (a shape being dragged past its edge).
fn (app &StudioApp) pixel_at(x int, y int) (int, int) {
	ox, oy := app.canvas_origin()
	cell := app.cell()
	px := (x - ox) / cell - if x < ox { 1 } else { 0 }
	py := (y - oy) / cell - if y < oy { 1 } else { 0 }
	return px, py
}

// ── Pointer ────────────────────────────────────────────────────────

fn (mut app StudioApp) pointer_input_enabled() bool {
	return true
}

fn (mut app StudioApp) pointer_moves_matter() bool {
	return app.drawing
}

fn (mut app StudioApp) pointer_event(phase AppPointerPhase, button AppPointerButton, scroll int, x int, y int, width int, height int) {
	app.initialize()
	if app.tab != studio_tab_paint {
		return
	}
	px, py := app.pixel_at(x, y)
	match phase {
		.down {
			if button != .left || !app.doc.inside(px, py) {
				return
			}
			app.begin_stroke(px, py)
		}
		.move {
			if app.drawing {
				app.continue_stroke(px, py)
			}
		}
		.up {
			if app.drawing {
				app.continue_stroke(px, py)
				app.drawing = false
				app.base = []u32{}
			}
		}
		else {}
	}
}

fn (mut app StudioApp) begin_stroke(px int, py int) {
	match app.tool {
		.picker {
			picked := app.doc.at(px, py)
			app.colour = picked
			app.sync_hex()
			// Like Paint, picking a colour goes back to drawing with it.
			app.tool = .pencil
			return
		}
		.fill {
			app.doc.checkpoint()
			app.doc.flood_fill(px, py, app.colour)
			return
		}
		else {}
	}
	app.doc.checkpoint()
	app.drawing = true
	app.start_x = px
	app.start_y = py
	app.last_x = px
	app.last_y = py
	if paint_tool_is_shape(app.tool) {
		app.base = app.doc.pixels.clone()
		app.doc.draw_shape(app.tool, px, py, px, py, app.brush, app.colour)
	} else {
		app.doc.stamp(px, py, app.brush, if app.tool == .eraser { u32(0) } else { app.colour })
	}
}

fn (mut app StudioApp) continue_stroke(px int, py int) {
	if paint_tool_is_shape(app.tool) {
		// The shape is redrawn from what was there when the press began, so it
		// follows the pointer and leaves nothing behind.
		app.doc.pixels = app.base.clone()
		app.doc.draw_shape(app.tool, app.start_x, app.start_y, px, py, app.brush, app.colour)
	} else {
		colour := if app.tool == .eraser { u32(0) } else { app.colour }
		app.doc.draw_line(app.last_x, app.last_y, px, py, app.brush, colour)
	}
	app.last_x = px
	app.last_y = py
}

// ── Actions ────────────────────────────────────────────────────────

fn studio_index_of(ids []string, action string) int {
	for index, id in ids {
		if id == action {
			return index
		}
	}
	return -1
}

fn (mut app StudioApp) handle(action string) ! {
	app.initialize()
	match action {
		'studio.tab.0' {
			app.tab = studio_tab_paint
			return
		}
		'studio.tab.1' {
			app.tab = studio_tab_skin
			app.refresh_previews()
			return
		}
		'studio.grid' {
			app.grid = !app.grid
			return
		}
		'studio.undo' {
			app.doc.undo_step()
			return
		}
		'studio.redo' {
			app.doc.redo_step()
			return
		}
		'studio.clear' {
			app.doc.clear()
			return
		}
		'studio.id' {
			app.focus = .skin_id
			app.selected = true
			return
		}
		'studio.file' {
			app.focus = .file
			app.selected = true
			return
		}
		'studio.hex' {
			app.focus = .colour
			app.selected = true
			return
		}
		'studio.name' {
			app.focus = .skin_name
			app.selected = true
			return
		}
		'studio.hex_set' {
			app.apply_hex()
			return
		}
		'studio.save' {
			app.save_picture()
			return
		}
		'studio.open' {
			app.open_picture()
			return
		}
		'studio.save_skin' {
			app.save_skin()
			return
		}
		'studio.open_skin' {
			app.open_skin()
			return
		}
		else {}
	}
	if index := studio_index_ok(studio_index_of(studio_tool_ids[..], action)) {
		app.tool = studio_tools[index]
	} else if index := studio_index_ok(studio_index_of(studio_brush_ids[..], action)) {
		app.brush = studio_brush_sizes[index]
	} else if index := studio_index_ok(studio_index_of(studio_size_ids[..], action)) {
		side := studio_sizes[index]
		app.doc.resize(side, side)
	} else if index := studio_index_ok(studio_index_of(studio_pal_ids[..], action)) {
		app.colour = studio_palette[index]
		app.sync_hex()
	} else if index := studio_index_ok(studio_index_of(studio_plate_ids[..], action)) {
		app.skin.plate = unsafe { StudioPlate(index) }
	} else if index := studio_index_ok(studio_index_of(studio_use_ids[..], action)) {
		app.use_drawing(index)
	} else if index := studio_index_ok(studio_index_of(studio_edit_ids[..], action)) {
		app.edit_widget(index)
	} else if index := studio_index_ok(studio_index_of(studio_remove_ids[..], action)) {
		app.skin.widgets[index] = StudioWidget{}
		app.previews[index] = new_paint_doc(1, 1)
	}
}

fn studio_index_ok(index int) ?int {
	if index < 0 {
		return none
	}
	return index
}

// ── Colour ─────────────────────────────────────────────────────────

fn (mut app StudioApp) sync_hex() {
	if app.colour >> 24 == 0 {
		app.hex_input = studio_bytes('none')
		return
	}
	digits := '0123456789abcdef'
	mut text := '#'
	for shift in [20, 16, 12, 8, 4, 0] {
		text += digits[int((app.colour >> u32(shift)) & 15)].ascii_str()
	}
	app.hex_input = studio_bytes(text)
}

fn (mut app StudioApp) apply_hex() {
	text := editor_bytes_text(app.hex_input)
	if text == 'none' {
		app.colour = 0
		app.status = 'studio.ready'
		return
	}
	value := parse_hex_color(text) or {
		app.status = 'studio.bad_colour'
		return
	}
	app.colour = 0xff000000 | value
	app.status = 'studio.ready'
}

// ── Files ──────────────────────────────────────────────────────────

fn (app &StudioApp) skin_dir() ?string {
	id := editor_bytes_text(app.id_input)
	if !skin_id_valid(id) {
		return none
	}
	return '${skin_user_root()}/${id}'
}

fn (mut app StudioApp) picture_path() ?string {
	dir := app.skin_dir() or {
		app.status = 'studio.bad_id'
		return none
	}
	name := editor_bytes_text(app.file_input)
	if !skin_file_name_valid('${name}.png') {
		app.status = 'studio.bad_file'
		return none
	}
	return '${dir}/${name}.png'
}

fn (mut app StudioApp) save_picture() {
	path := app.picture_path() or { return }
	dir := os.dir(path)
	os.mkdir_all(dir) or {
		app.status = 'studio.save_failed'
		return
	}
	if paint_save_png(path, &app.doc) {
		app.status = 'studio.saved'
		app.detail = path.clone()
	} else {
		app.status = 'studio.save_failed'
	}
}

fn (mut app StudioApp) open_picture() {
	path := app.picture_path() or { return }
	doc := paint_load_png(path) or {
		app.status = 'studio.open_failed'
		return
	}
	app.doc = doc
	app.status = 'studio.opened'
	app.detail = path.clone()
}

// use_drawing keeps the picture being drawn as a control's art, in the skin's
// folder, and the skin's note of it.
fn (mut app StudioApp) use_drawing(index int) {
	dir := app.skin_dir() or {
		app.status = 'studio.bad_id'
		return
	}
	os.mkdir_all(dir) or {
		app.status = 'studio.save_failed'
		return
	}
	file := studio_widget_file(index)
	if !paint_save_png('${dir}/${file}', &app.doc) {
		app.status = 'studio.save_failed'
		return
	}
	app.skin.widgets[index] = StudioWidget{
		file: file
		art: app.doc.width
	}
	app.previews[index] = PaintDoc{
		width: app.doc.width
		height: app.doc.height
		pixels: app.doc.pixels.clone()
	}
	app.status = 'studio.saved'
}

// edit_widget brings a control's picture back into the editor.
fn (mut app StudioApp) edit_widget(index int) {
	widget := app.skin.widgets[index]
	if widget.file.len == 0 {
		app.status = 'studio.no_art'
		return
	}
	dir := app.skin_dir() or {
		app.status = 'studio.bad_id'
		return
	}
	doc := paint_load_png('${dir}/${widget.file}') or {
		app.status = 'studio.open_failed'
		return
	}
	app.doc = doc
	app.tab = studio_tab_paint
	app.status = 'studio.opened'
}

fn (mut app StudioApp) save_skin() {
	app.sync_skin_fields()
	dir := app.skin_dir() or {
		app.status = 'studio.bad_id'
		return
	}
	os.mkdir_all(dir) or {
		app.status = 'studio.skin_save_failed'
		return
	}
	text := app.skin.cfg()
	path := '${dir}/skin.cfg'
	if desktop_write_file(path, text.str, u64(text.len)) {
		app.status = 'studio.skin_saved'
		app.detail = dir.clone()
	} else {
		app.status = 'studio.skin_save_failed'
	}
}

fn (mut app StudioApp) open_skin() {
	dir := app.skin_dir() or {
		app.status = 'studio.bad_id'
		return
	}
	text := read_skin_cfg(dir) or {
		app.status = 'studio.skin_open_failed'
		return
	}
	id := editor_bytes_text(app.id_input).clone()
	app.skin = studio_skin_from_cfg(id, text)
	app.name_input = studio_bytes(app.skin.name)
	app.refresh_previews()
	app.status = 'studio.skin_opened'
	app.detail = dir.clone()
}

// refresh_previews reads each control's picture so the skin page can show it.
fn (mut app StudioApp) refresh_previews() {
	dir := app.skin_dir() or { return }
	for index in 0 .. 5 {
		widget := app.skin.widgets[index]
		if widget.file.len == 0 {
			continue
		}
		if doc := paint_load_png('${dir}/${widget.file}') {
			app.previews[index] = doc
		}
	}
}

// ── Keyboard ───────────────────────────────────────────────────────

fn (app &StudioApp) field_accepts(byte u8) bool {
	return match app.focus {
		.skin_id { (byte >= `a` && byte <= `z`) || (byte >= `0` && byte <= `9`) || byte == `-` || byte == `_` }
		.file { (byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`) || (byte >= `0` && byte <= `9`) || byte == `-` || byte == `_` }
		.colour { (byte >= `0` && byte <= `9`) || (byte >= `a` && byte <= `f`) || (byte >= `A` && byte <= `F`) || byte == `#` || byte == `n` || byte == `o` || byte == `e` }
		.skin_name { byte >= 32 && byte < 127 }
		.none_ { false }
	}
}

fn (mut app StudioApp) key_input(input string) {
	app.initialize()
	if input.len > 1 && input[0] == 27 {
		return
	}
	for byte in input {
		match byte {
			26 { app.doc.undo_step() }
			25 { app.doc.redo_step() }
			27 { app.focus = .none_ }
			9 {
				app.focus = match app.focus {
					.none_ { StudioField.skin_id }
					.skin_id { StudioField.file }
					.file { StudioField.colour }
					.colour { StudioField.skin_name }
					.skin_name { StudioField.none_ }
				}
				app.selected = true
			}
			13, 10 {
				match app.focus {
					.file { app.save_picture() }
					.colour { app.apply_hex() }
					.skin_name { app.save_skin() }
					else {}
				}
			}
			8, 127 {
				match app.focus {
					.skin_id { console_backspace(mut app.id_input, app.selected) }
					.file { console_backspace(mut app.file_input, app.selected) }
					.colour { console_backspace(mut app.hex_input, app.selected) }
					.skin_name { console_backspace(mut app.name_input, app.selected) }
					.none_ {}
				}
				app.selected = false
				app.sync_skin_fields()
			}
			else {
				if !app.field_accepts(byte) {
					continue
				}
				character := unsafe { tos(&byte, 1) }
				match app.focus {
					.skin_id { console_edit_character(mut app.id_input, character, 32, app.selected) }
					.file { console_edit_character(mut app.file_input, character, 24, app.selected) }
					.colour { console_edit_character(mut app.hex_input, character, 7, app.selected) }
					.skin_name { console_edit_character(mut app.name_input, character, 32, app.selected) }
					.none_ {}
				}
				app.selected = false
				app.sync_skin_fields()
			}
		}
	}
}

fn (mut app StudioApp) paste_input(text string) {
	app.key_input(text)
}

// ── Elements ───────────────────────────────────────────────────────

fn studio_button(id string, label string, x int, y int, width int, height int, active bool) ui2.Element {
	return ui2.button(id, label, ui2.rect(f64(x), f64(y), f64(width), f64(height)), ui2.BoxStyle{
		bg: if active { app_accent } else { settings_choice_bg }
		radius: 4
	}, ui2.TextStyle{
		color: if active { app_on_accent } else { body_text }
		size: 11
		align: .center
	})
}

fn studio_label(text string, x int, y int, width int) ui2.Element {
	return ui2.label('', text, ui2.rect(f64(x), f64(y), f64(width), 16), ui2.TextStyle{
		size: 11
		color: body_muted
	})
}

fn studio_box(x int, y int, width int, height int, color u32) ui2.Element {
	return ui2.view('', ui2.rect(f64(x), f64(y), f64(width), f64(height)), ui2.BoxStyle{
		bg: color & 0xffffff
	}, [])
}

// picture_elements draws a picture `scale` screen pixels to a pixel, as one box
// per run, on a flat ground the size of the picture.
fn picture_elements(doc &PaintDoc, scale int, ground u32) []ui2.Element {
	runs := doc.runs()
	mut out := frame_elements(runs.len + 1)
	out << studio_box(0, 0, doc.width * scale, doc.height * scale, ground)
	for run in runs {
		out << studio_box(run.x * scale, run.y * scale, run.width * scale, scale, run.color)
	}
	return out
}

fn (app &StudioApp) canvas_element() ui2.Element {
	cell := app.cell()
	ox, oy := app.canvas_origin()
	mut cells := picture_elements(&app.doc, cell, studio_ground)
	if app.grid && cell >= 6 {
		for i in 1 .. app.doc.width {
			cells << studio_box(i * cell, 0, 1, app.doc.height * cell, studio_grid_color)
		}
		for j in 1 .. app.doc.height {
			cells << studio_box(0, j * cell, app.doc.width * cell, 1, studio_grid_color)
		}
	}
	return ui2.view('studio.canvas', ui2.rect(f64(ox), f64(oy), f64(app.doc.width * cell),
		f64(app.doc.height * cell)), ui2.BoxStyle{}, cells)
}

fn (mut app StudioApp) build(size ui2.Rect) !ui2.Element {
	app.initialize()
	width := int(size.width)
	height := int(size.height)
	mut children := frame_elements(80)
	children << studio_button('studio.tab.0', tr('studio.tab.paint'), 8, 8, 72, 28, app.tab == studio_tab_paint)
	children << studio_button('studio.tab.1', tr('studio.tab.skin'), 86, 8, 72, 28, app.tab == studio_tab_skin)
	children << studio_label(tr('studio.skin_id'), width - 330, 16, 90)
	children << studio_field('studio.id', editor_bytes_text(app.id_input), width - 236, 6, 224, app.focus == .skin_id)
	if app.tab == studio_tab_paint {
		app.paint_elements(mut children, width, height)
	} else {
		app.skin_elements(mut children, width, height)
	}
	children << ui2.label('', tr(app.status), ui2.rect(8, f64(height - 24), f64(width - 16), 18), ui2.TextStyle{
		size: 11
		color: body_text
	})
	return ui2.screen(app_surface, children)
}

fn studio_field(id string, value string, x int, y int, width int, focused bool) ui2.Element {
	return console_field(id, value, x, y, width, focused)
}

fn (app &StudioApp) paint_elements(mut children []ui2.Element, width int, height int) {
	for index in 0 .. studio_tools.len {
		children << studio_button(studio_tool_ids[index], tr(studio_tool_keys[index]), 8, 52 + index * 30, 84, 26, app.tool == studio_tools[index])
	}
	children << studio_label(tr('studio.brush'), 8, 328, 84)
	for index in 0 .. studio_brush_sizes.len {
		children << studio_button(studio_brush_ids[index], studio_brush_sizes[index].str(), 8 + index * 22, 346, 20, 24, app.brush == studio_brush_sizes[index])
	}
	children << studio_button('studio.grid', tr('studio.grid'), 8, 378, 84, 24, app.grid)
	children << studio_button('studio.undo', tr('studio.undo'), 8, 408, 40, 24, false)
	children << studio_button('studio.redo', tr('studio.redo'), 52, 408, 40, 24, false)
	children << studio_button('studio.clear', tr('studio.clear'), 8, 438, 84, 24, false)
	children << studio_label(tr('studio.size'), 8, 468, 84)
	for index in 0 .. studio_sizes.len {
		children << studio_button(studio_size_ids[index], studio_sizes[index].str(), 8 + (index % 3) * 29, 486 + (index / 3) * 28, 27, 24, app.doc.width == studio_sizes[index] && app.doc.height == studio_sizes[index])
	}
	children << app.canvas_element()

	// The palette, under the picture.
	palette_y := studio_canvas_y + studio_canvas_span + 8
	for index in 0 .. studio_palette.len {
		x := studio_canvas_x + (index % 15) * 26
		y := palette_y + (index / 15) * 26
		colour := studio_palette[index]
		selected := colour == app.colour
		children << ui2.view(studio_pal_ids[index], ui2.rect(f64(x), f64(y), 24, 24), ui2.BoxStyle{
			bg: if colour >> 24 == 0 { u32(0xffffff) } else { colour & 0xffffff }
			border_color: if selected { app_accent } else { body_rule }
			border_left: if selected { 2 } else { 1 }
			border_right: if selected { 2 } else { 1 }
			border_top: if selected { 2 } else { 1 }
			border_bottom: if selected { 2 } else { 1 }
		}, if colour >> 24 == 0 { [studio_box(4, 11, 16, 2, 0xe5484d)] } else { []ui2.Element{} })
	}

	// The right-hand column: a preview, the file and the colour.
	right := width - 212
	children << studio_label(tr('studio.preview'), right, 52, 200)
	longest := if app.doc.width > app.doc.height { app.doc.width } else { app.doc.height }
	scale := clamp_int(150 / longest, 1, 8)
	preview := picture_elements(&app.doc, scale, 0xc0c0c0)
	children << ui2.view('', ui2.rect(f64(right), 72, f64(app.doc.width * scale), f64(app.doc.height * scale)), ui2.BoxStyle{}, preview)
	children << studio_label(tr('studio.file'), right, 250, 200)
	children << studio_field('studio.file', editor_bytes_text(app.file_input), right, 268, 204, app.focus == .file)
	children << studio_button('studio.save', tr('studio.save'), right, 304, 98, 26, false)
	children << studio_button('studio.open', tr('studio.open'), right + 106, 304, 98, 26, false)
	children << studio_label(tr('studio.colour'), right, 346, 200)
	children << studio_field('studio.hex', editor_bytes_text(app.hex_input), right, 364, 130, app.focus == .colour)
	children << studio_button('studio.hex_set', tr('studio.set'), right + 138, 366, 66, 26, false)
	children << ui2.view('', ui2.rect(f64(right), 404, 204, 28), ui2.BoxStyle{
		bg: if app.colour >> 24 == 0 { u32(0xffffff) } else { app.colour & 0xffffff }
		border_color: body_rule
		border_left: 1
		border_right: 1
		border_top: 1
		border_bottom: 1
	}, [])
	if app.detail.len > 0 {
		children << ui2.label('', app.detail, ui2.rect(f64(right), 440, 204, 48), ui2.TextStyle{
			size: 10
			color: body_muted
			lines: 3
		})
	}
}

// plate_elements is a control's plate at its real size, built from boxes: the
// outline, the face (two tones for a shaded plate) and the light and dark edges.
fn studio_plate_elements(plate StudioPlate, side int) []ui2.Element {
	cfg := studio_plate_cfg(plate)
	mut out := []ui2.Element{}
	drawable := parse_drawable(cfg) or { return out }
	out << studio_box(0, 0, side, side, drawable.outline)
	top_face := drawable.color
	bottom_face := if drawable.face2 != 0 { drawable.face2 } else { drawable.color }
	out << studio_box(1, 1, side - 2, (side - 2) / 2, top_face)
	out << studio_box(1, 1 + (side - 2) / 2, side - 2, side - 2 - (side - 2) / 2, bottom_face)
	out << studio_box(1, 1, side - 2, 1, drawable.light)
	out << studio_box(1, 1, 1, side - 2, drawable.light)
	out << studio_box(1, side - 2, side - 2, 1, drawable.dark)
	out << studio_box(side - 2, 1, 1, side - 2, drawable.dark)
	return out
}

fn (app &StudioApp) skin_elements(mut children []ui2.Element, width int, height int) {
	children << studio_label(tr('studio.skin_name'), 8, 52, 200)
	children << studio_field('studio.name', editor_bytes_text(app.name_input), 8, 70, 300, app.focus == .skin_name)
	children << studio_label(tr('studio.plate'), 330, 52, 200)
	for index in 0 .. studio_plate_ids.len {
		children << studio_button(studio_plate_ids[index], tr(studio_plate_keys[index]), 330 + index * 110, 72, 104, 26, int(app.skin.plate) == index)
	}
	for index in 0 .. 5 {
		y := 120 + index * 66
		widget := app.skin.widgets[index]
		children << ui2.label('', tr(studio_widget_keys[index]), ui2.rect(8, f64(y + 16), 96, 20), ui2.TextStyle{
			size: 12
			color: body_text
			bold: true
		})
		children << ui2.label('', if widget.file.len > 0 { widget.file } else { tr('studio.no_art') }, ui2.rect(110, f64(y + 18), 150, 16), ui2.TextStyle{
			size: 11
			color: body_muted
		})
		children << studio_button(studio_use_ids[index], tr('studio.use'), 270, y + 12, 120, 26, false)
		children << studio_button(studio_edit_ids[index], tr('studio.edit'), 396, y + 12, 64, 26, false)
		children << studio_button(studio_remove_ids[index], tr('studio.remove'), 466, y + 12, 76, 26, false)
		// The control as the desktop will draw it: plate, then the picture in the
		// middle half of it, or the picture alone.
		preview := app.previews[index]
		art := if widget.file.len > 0 { preview.width } else { 0 }
		if art > 0 {
			side := studio_control_size(widget.art, app.skin.plate)
			mut parts := []ui2.Element{}
			if app.skin.plate != .none_ {
				parts << ui2.view('', ui2.rect(0, 0, f64(side), f64(side)), ui2.BoxStyle{}, studio_plate_elements(app.skin.plate, side))
			}
			margin := if app.skin.plate != .none_ { side / 4 } else { 0 }
			inner := side - 2 * margin
			scale := if preview.width > 0 && inner >= preview.width { inner / preview.width } else { 1 }
			parts << ui2.view('', ui2.rect(f64(margin), f64(margin), f64(preview.width * scale), f64(preview.height * scale)), ui2.BoxStyle{}, picture_elements(&preview, scale, 0))
			children << ui2.view('', ui2.rect(570, f64(y + 2), f64(side), f64(side)), ui2.BoxStyle{}, parts)
		}
	}
	children << studio_button('studio.save_skin', tr('studio.save_skin'), 8, height - 64, 140, 28, false)
	children << studio_button('studio.open_skin', tr('studio.open_skin'), 156, height - 64, 140, 28, false)
	if app.detail.len > 0 {
		children << ui2.label('', app.detail, ui2.rect(304, f64(height - 62), f64(width - 312), 32), ui2.TextStyle{
			size: 10
			color: body_muted
			lines: 2
		})
	}
}
