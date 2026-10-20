// SPDX-License-Identifier: GPL-2.0-or-later
@[has_globals]
module main

import os
import ui2

// Theme Studio: drawing with the pointer, the files it writes, and the skin it
// builds from them.

fn studio_fixture() &StudioApp {
	mut app := &StudioApp{}
	app.initialize()
	return app
}

// A press, a drag and a release at the middle of the picture's cells.
fn studio_cell_point(app &StudioApp, px int, py int) (int, int) {
	ox, oy := app.canvas_origin()
	cell := app.cell()
	return ox + px * cell + cell / 2, oy + py * cell + cell / 2
}

fn studio_drag(mut app StudioApp, from_x int, from_y int, to_x int, to_y int) {
	fx, fy := studio_cell_point(app, from_x, from_y)
	tx, ty := studio_cell_point(app, to_x, to_y)
	app.pointer_event(.down, .left, 0, fx, fy, 780, 560)
	app.pointer_event(.move, .left, 0, tx, ty, 780, 560)
	app.pointer_event(.up, .left, 0, tx, ty, 780, 560)
}

fn studio_temp_skins() string {
	dir := os.join_path(os.temp_dir(), 'vinix-studio-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { panic(err) }
	os.setenv('VINIX_USER_SKIN_DIR', dir, true)
	return dir
}

fn test_the_pencil_draws_where_the_pointer_goes() {
	mut app := studio_fixture()
	studio_drag(mut app, 2, 3, 6, 3)
	for x in 2 .. 7 {
		assert app.doc.at(x, 3) == 0xff000000
	}
	assert app.doc.at(1, 3) == 0
	assert app.doc.at(7, 3) == 0
	assert !app.drawing
}

fn test_a_press_outside_the_picture_draws_nothing() {
	mut app := studio_fixture()
	app.pointer_event(.down, .left, 0, 2, 2, 780, 560)
	app.pointer_event(.up, .left, 0, 2, 2, 780, 560)
	for pixel in app.doc.pixels {
		assert pixel == 0
	}
}

fn test_a_shape_follows_the_pointer_and_leaves_no_trail() {
	mut app := studio_fixture()
	app.handle('studio.tool.5') or { panic(err) } // box
	fx, fy := studio_cell_point(app, 2, 2)
	app.pointer_event(.down, .left, 0, fx, fy, 780, 560)
	far_x, far_y := studio_cell_point(app, 12, 12)
	app.pointer_event(.move, .left, 0, far_x, far_y, 780, 560)
	assert app.doc.at(12, 12) == 0xff000000
	near_x, near_y := studio_cell_point(app, 5, 5)
	app.pointer_event(.move, .left, 0, near_x, near_y, 780, 560)
	// The larger box is gone, the smaller one is there.
	assert app.doc.at(12, 12) == 0
	assert app.doc.at(5, 5) == 0xff000000
	app.pointer_event(.up, .left, 0, near_x, near_y, 780, 560)
	assert app.doc.at(5, 5) == 0xff000000
	assert app.doc.at(12, 2) == 0
}

fn test_the_picker_takes_a_colour_and_goes_back_to_the_pencil() {
	mut app := studio_fixture()
	app.handle('studio.pal.2') or { panic(err) } // maroon
	studio_drag(mut app, 4, 4, 4, 4)
	app.handle('studio.pal.0') or { panic(err) } // black
	app.handle('studio.tool.3') or { panic(err) } // picker
	studio_drag(mut app, 4, 4, 4, 4)
	assert app.colour == 0xff800000
	assert app.tool == .pencil
	assert editor_bytes_text(app.hex_input) == '#800000'
}

fn test_the_eraser_makes_transparent_pixels_and_undo_brings_them_back() {
	mut app := studio_fixture()
	studio_drag(mut app, 1, 1, 3, 1)
	app.handle('studio.tool.1') or { panic(err) } // eraser
	studio_drag(mut app, 2, 1, 2, 1)
	assert app.doc.at(2, 1) == 0
	app.handle('studio.undo') or { panic(err) }
	assert app.doc.at(2, 1) == 0xff000000
}

fn test_fill_covers_a_region_in_one_press() {
	mut app := studio_fixture()
	app.handle('studio.pal.16') or { panic(err) } // red
	app.handle('studio.tool.2') or { panic(err) } // fill
	studio_drag(mut app, 0, 0, 0, 0)
	assert app.doc.at(15, 15) == 0xffff0000
}

fn test_a_custom_colour_is_typed_in_as_hex() {
	mut app := studio_fixture()
	app.handle('studio.hex') or { panic(err) }
	app.key_input('#336699')
	app.key_input('\r')
	assert app.colour == 0xff336699
	// Letters that are not digits are not typed.
	app.handle('studio.hex') or { panic(err) }
	app.key_input('zz#12')
	assert editor_bytes_text(app.hex_input) == '#12'
	app.key_input('\r')
	assert app.status == 'studio.bad_colour'
}

fn test_the_picture_is_resized_from_the_size_buttons() {
	mut app := studio_fixture()
	studio_drag(mut app, 1, 1, 1, 1)
	app.handle('studio.size.3') or { panic(err) } // 32
	assert app.doc.width == 32
	assert app.doc.height == 32
	assert app.doc.at(1, 1) == 0xff000000
	assert app.cell() == 13
}

fn test_the_biggest_picture_stays_inside_the_protocols_limits() {
	mut app := studio_fixture()
	app.doc = new_paint_doc(paint_max_side, paint_max_side)
	// The worst case for runs: every pixel a different colour from its
	// neighbours.
	for y in 0 .. paint_max_side {
		for x in 0 .. paint_max_side {
			app.doc.set(x, y, 0xff000000 | u32((x + y * 7) % 2 * 0xffffff))
		}
	}
	root := app.build(ui2.rect(0, 0, 780, 560)) or { panic(err) }
	assert studio_count(root) < app_protocol_max_elements
}

fn studio_count(root ui2.Element) int {
	mut count := 1
	for child in root.children {
		count += studio_count(child)
	}
	return count
}

fn studio_ids(root ui2.Element, mut out []string) {
	if root.id.len > 0 {
		out << root.id
	}
	for child in root.children {
		studio_ids(child, mut out)
	}
}

fn test_the_paint_page_offers_every_tool_and_colour() {
	mut app := studio_fixture()
	root := app.build(ui2.rect(0, 0, 780, 560)) or { panic(err) }
	mut ids := []string{}
	studio_ids(root, mut ids)
	for id in studio_tool_ids {
		assert id in ids
	}
	for id in studio_pal_ids {
		assert id in ids
	}
	assert 'studio.canvas' in ids
	assert 'studio.save' in ids
}

fn test_a_picture_survives_saving_and_opening_with_its_transparency() {
	dir := studio_temp_skins()
	defer {
		os.rmdir_all(dir) or {}
	}
	mut app := studio_fixture()
	studio_drag(mut app, 2, 2, 5, 2)
	app.save_picture()
	assert app.status == 'studio.saved'
	assert os.exists('${dir}/my-skin/close.png')
	mut other := studio_fixture()
	other.open_picture()
	assert other.status == 'studio.opened'
	assert other.doc.width == 16
	assert other.doc.at(3, 2) == 0xff000000
	assert other.doc.at(3, 3) == 0
}

fn test_a_file_name_with_a_path_is_refused() {
	dir := studio_temp_skins()
	defer {
		os.rmdir_all(dir) or {}
	}
	mut app := studio_fixture()
	app.handle('studio.file') or { panic(err) }
	app.key_input('../evil')
	// The slashes and dots are not letters, so they are not typed at all.
	assert editor_bytes_text(app.file_input) == 'evil'
	app.save_picture()
	assert !os.exists('${dir}/evil.png')
}

fn test_a_skin_is_made_from_drawings_and_the_desktop_lists_it() {
	dir := studio_temp_skins()
	defer {
		os.rmdir_all(dir) or {}
	}
	mut app := studio_fixture()
	app.doc = new_paint_doc(10, 10)
	app.doc.draw_rect(1, 1, 8, 8, 1, 0xff000000, true)
	app.handle('studio.plate.1') or { panic(err) }
	app.handle('studio.use.0') or { panic(err) }
	app.handle('studio.use.2') or { panic(err) }
	assert app.skin.widgets[0].file == 'close.png'
	assert app.skin.widgets[2].file == 'maximize.png'
	app.handle('studio.save_skin') or { panic(err) }
	assert app.status == 'studio.skin_saved'
	text := os.read_file('${dir}/my-skin/skin.cfg') or { panic(err) }
	parsed := parse_skin('my-skin', '', text)
	assert parsed.problems.len == 0
	assert text.contains('widget.close.size=20')
	// The Skins page of Settings finds it.
	skin_catalog_cache.loaded = false
	assert skin_catalog().any(it.id == 'my-skin')
	// And it can be opened again.
	mut again := studio_fixture()
	again.open_skin()
	assert again.status == 'studio.skin_opened'
	assert again.skin.plate == .grey
	assert again.skin.widgets[2].file == 'maximize.png'
}

fn test_the_skin_page_shows_a_control_with_its_plate() {
	dir := studio_temp_skins()
	defer {
		os.rmdir_all(dir) or {}
	}
	mut app := studio_fixture()
	app.doc = new_paint_doc(10, 10)
	app.doc.draw_rect(2, 2, 7, 7, 1, 0xff000000, true)
	app.handle('studio.plate.2') or { panic(err) }
	app.handle('studio.use.1') or { panic(err) }
	app.handle('studio.tab.1') or { panic(err) }
	root := app.build(ui2.rect(0, 0, 780, 560)) or { panic(err) }
	mut ids := []string{}
	studio_ids(root, mut ids)
	assert 'studio.save_skin' in ids
	for id in studio_use_ids {
		assert id in ids
	}
}
