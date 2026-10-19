// SPDX-License-Identifier: GPL-2.0-or-later
@[has_globals]
module main

import os

// The user's own skins: found in their folder, loaded from it, drawn from SVG
// and PNG files.

const test_png_2x2 = [u8(0x89), 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x08, 0x06, 0x00, 0x00, 0x00, 0x72, 0xb6, 0x0d, 0x24, 0x00, 0x00, 0x00, 0x19, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x05, 0xc1, 0x01, 0x0d, 0x00, 0x00, 0x08, 0xc0, 0x20, 0xdc, 0x2c, 0x6e, 0xf2, 0x0b, 0x22, 0x69, 0x47, 0xe2, 0x1e, 0x3f, 0x80, 0x06, 0x81, 0xa3, 0x55, 0xfe, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]!

fn skin_fixture_dir() string {
	dir := os.join_path(os.temp_dir(), 'vinix-skin-test-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(os.join_path(dir, 'mine')) or { panic(err) }
	os.mkdir_all(os.join_path(dir, 'broken')) or { panic(err) }
	os.mkdir_all(os.join_path(dir, 'Not Valid')) or { panic(err) }
	os.mkdir_all(os.join_path(dir, 'beos-boxes')) or { panic(err) }
	os.write_file(os.join_path(dir, 'mine', 'skin.cfg'),
		'name=My skin\nwidget.close=vector:cross.svg\nwidget.maximize=bitmap:box.png\nwidget.close.size=14\n') or {
		panic(err)
	}
	os.write_file(os.join_path(dir, 'mine', 'cross.svg'),
		'<svg viewBox="0 0 12 12"><path d="M0 0 H12 V12 H0 Z"/></svg>') or { panic(err) }
	os.write_file_array(os.join_path(dir, 'mine', 'box.png'), test_png_2x2[..]) or { panic(err) }
	os.write_file(os.join_path(dir, 'broken', 'nothing.txt'), 'no skin.cfg here') or { panic(err) }
	os.write_file(os.join_path(dir, 'beos-boxes', 'skin.cfg'), 'name=Impostor\n') or { panic(err) }
	return dir
}

fn test_the_users_skins_are_listed_after_the_built_in_ones() {
	dir := skin_fixture_dir()
	defer {
		os.rmdir_all(dir) or {}
	}
	os.setenv('VINIX_USER_SKIN_DIR', dir, true)
	os.setenv('VINIX_SKIN_DIR', os.join_path(dir, 'no-such-installed-dir'), true)
	skins := list_skins()
	ids := skins.map(it.id)
	// Built-in first, in their order.
	for i, id in builtin_skin_ids {
		assert skins[i].id == id
	}
	assert 'mine' in ids
	assert skins[ids.index('mine')].name == 'My skin'
	// A folder with no skin.cfg, an invalid name, and one that borrows a built-in's
	// name are all left out.
	assert 'broken' !in ids
	assert ids.filter(it == 'beos-boxes').len == 1
	assert skins.filter(it.name == 'Impostor').len == 0
	// The built-in skin is not replaced by the folder of the same name.
	loaded := load_skin('beos-boxes') or { panic('built-in lost') }
	assert loaded.dir.starts_with('builtin:')
}

fn test_a_users_skin_loads_from_their_folder_and_draws_svg_and_png() {
	dir := skin_fixture_dir()
	defer {
		os.rmdir_all(dir) or {}
	}
	os.setenv('VINIX_USER_SKIN_DIR', dir, true)
	os.setenv('VINIX_SKIN_DIR', os.join_path(dir, 'no-such-installed-dir'), true)
	skin := load_skin('mine') or { panic('not loaded') }
	assert skin.name == 'My skin'
	assert skin.problems.len == 0
	mut d := Desktop{}
	d.skin_state = SkinState{
		id: 'mine'
		skin: skin
		loaded: true
	}
	assert d.skin_active()
	close := d.skin_widget('close') or { panic('no close') }
	assert close.normal.kind == .vector && close.size == 14
	// The SVG is read as a vector and rasterises solid.
	mask := d.skin_mask('cross.svg', 8, 8) or { panic('svg did not load') }
	assert mask.filter(it > 127).len == 64
	// The PNG decodes to its four pixels, with the alpha it was given.
	bm := d.skin_bitmap('box.png') or { panic('png did not load') }
	assert bm.width == 2 && bm.height == 2
	assert bm.pixels[0] == 0xffff0000
	assert bm.pixels[1] == 0xff00ff00
	assert bm.pixels[2] == 0xff0000ff
	assert (bm.pixels[3] >> 24) == 0x80
	// Files that are not there, or not what they claim, fail once and quietly.
	assert d.skin_bitmap('missing.png') == none
	assert d.skin_vector('missing.svg') == none
	assert 'missing.png' in d.skin_state.failed
	// Garbage with a PNG's name does not decode.
	assert decode_skin_png([u8(1), 2, 3]) == none
	mut bad := test_png_2x2[..].clone()
	bad[20] = 0xff // a width far past what a window's chrome can use
	assert decode_skin_png(bad) == none
}

fn test_a_skin_that_appears_later_is_found_when_the_desktop_is_asked_for_it() {
	dir := skin_fixture_dir()
	defer {
		os.rmdir_all(dir) or {}
	}
	os.setenv('VINIX_USER_SKIN_DIR', dir, true)
	os.setenv('VINIX_SKIN_DIR', os.join_path(dir, 'no-such-installed-dir'), true)
	skin_catalog_cache.loaded = false
	before := skin_catalog().len
	os.mkdir_all(os.join_path(dir, 'zlater')) or { panic(err) }
	os.write_file(os.join_path(dir, 'zlater', 'skin.cfg'), 'name=Later\n') or { panic(err) }
	// The old list does not have it; asking for its number (one past the end)
	// reads the list again, and it is added at the end so nothing else moves.
	assert skin_catalog().len == before
	assert skin_from_wire(?int(before + 1)) == 'zlater'
	assert skin_catalog().len == before + 1
	assert skin_catalog().last().id == 'zlater'
	// A number that nothing has is still nothing.
	assert skin_from_wire(?int(before + 50)) == ''
	skin_catalog_cache.loaded = false
}
