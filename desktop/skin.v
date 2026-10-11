// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Skins at run time (Blue spec B5): finding them, reading their art and drawing
// it. skin_model.v holds the formats and the arithmetic; this file is the part
// that touches the file system and the canvas.
//
// A skin is a directory under /usr/share/vinix/skins, listed in index.txt (one
// "<id> <name>" per line, written by the build, as the wallpapers are), holding
// a skin.cfg and the art it names. A few skins are compiled in, so a look such
// as BeOS can ship vector controls without any files.
module main

import ui2

const skin_dir = '/usr/share/vinix/skins'
const skin_index = '${skin_dir}/index.txt'
// The most a single skin asset may weigh; a window's chrome never needs more.
const skin_asset_max = 2 * 1024 * 1024
const skin_cache_masks = 64

struct SkinEntry {
	id   string
	name string
}

// SkinState is the loaded skin and what it has read so far. Nothing is read
// until it is drawn, and nothing is read twice.
struct SkinState {
mut:
	id      string
	skin    Skin
	loaded  bool
	bitmaps map[string]Bitmap
	vectors map[string]VectorShape
	masks   map[string][]u8
	// Files that would not load, so a broken asset is tried once, not per frame.
	failed map[string]bool
}

// list_skins is every skin the user can pick: the compiled-in ones, then the
// installed ones. A missing index only means none are installed.
fn list_skins() []SkinEntry {
	mut out := []SkinEntry{}
	for id in builtin_skin_ids {
		out << SkinEntry{
			id: id
			name: builtin_skin_name(id)
		}
	}
	info := desktop_stat(skin_index) or { return out }
	if info.size == 0 || info.size > 64 * 1024 {
		return out
	}
	mut buffer := []u8{len: int(info.size) + 1}
	got := desktop_read_file(skin_index, buffer.data, info.size)
	if got <= 0 {
		return out
	}
	text := unsafe { tos(buffer.data, int(got)) }
	for line in text.split_into_lines() {
		trimmed := line.trim_space()
		space := trimmed.index(' ') or { continue }
		id := trimmed[..space]
		if !skin_id_valid(id) || id in builtin_skin_ids {
			continue
		}
		out << SkinEntry{
			id: id
			name: trimmed[space + 1..].trim_space()
		}
	}
	return out
}

// skin_file_name_valid keeps a skin's references to plain files in its own
// directory: no separators, no dots at the front.
fn skin_file_name_valid(name string) bool {
	if name.len == 0 || name.len > 64 || name[0] == `.` {
		return false
	}
	for c in name {
		if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `-` || c == `_` || c == `.`) {
			return false
		}
	}
	return true
}

// read_skin_file is a file from a skin's directory, or a compiled-in asset.
fn read_skin_file(skin &Skin, file string) ?[]u8 {
	if !skin_file_name_valid(file) {
		return none
	}
	if skin.dir.starts_with('builtin:') {
		text := builtin_skin_asset(skin.id, file) or { return none }
		return text.bytes()
	}
	path := '${skin.dir}/${file}'
	info := desktop_stat(path) or { return none }
	if info.is_dir || info.size == 0 || info.size > u64(skin_asset_max) {
		return none
	}
	mut buffer := []u8{len: int(info.size)}
	got := desktop_read_file(path, buffer.data, info.size)
	if got != i64(info.size) {
		return none
	}
	return buffer
}

fn load_skin(id string) ?Skin {
	if !skin_id_valid(id) {
		return none
	}
	if cfg := builtin_skin_cfg(id) {
		return parse_skin(id, 'builtin:${id}', cfg)
	}
	dir := '${skin_dir}/${id}'
	path := '${dir}/skin.cfg'
	info := desktop_stat(path) or { return none }
	if info.is_dir || info.size == 0 || info.size > u64(skin_cfg_max) {
		return none
	}
	mut buffer := []u8{len: int(info.size) + 1}
	got := desktop_read_file(path, buffer.data, info.size)
	if got <= 0 {
		return none
	}
	return parse_skin(id, dir, unsafe { tos(buffer.data, int(got)) }.clone())
}

// effective_skin_id is the skin in force: the user's choice when they made one
// ('none' turning the preset's skin off), otherwise the look's own.
fn (d &Desktop) effective_skin_id() string {
	chosen := d.settings.skin_id
	if chosen == 'none' {
		return ''
	}
	if chosen.len > 0 {
		return chosen
	}
	return d.theme().chrome.skin
}

// sync_skin makes the loaded skin the one in force. A skin that will not load
// leaves the look as it is.
fn (mut d Desktop) sync_skin() {
	want := d.effective_skin_id()
	if d.skin_state.loaded && d.skin_state.id == want {
		return
	}
	if !d.skin_state.loaded && want.len == 0 && d.skin_state.id.len == 0 {
		d.skin_state.loaded = true
		return
	}
	d.skin_state = SkinState{
		id: want
		loaded: true
	}
	if want.len > 0 {
		if skin := load_skin(want) {
			d.skin_state.skin = skin
		} else {
			d.skin_state.id = ''
			eprintln('vinix-desktop: skin ${want} could not be loaded')
		}
	}
	d.dirty = true
}

fn (d &Desktop) skin_active() bool {
	return d.skin_state.loaded && d.skin_state.id.len > 0
}

fn (d &Desktop) skin_widget(action string) ?SkinWidget {
	if !d.skin_active() {
		return none
	}
	return d.skin_state.skin.widgets[action] or { return none }
}

fn (mut d Desktop) skin_bitmap(file string) ?Bitmap {
	if file in d.skin_state.bitmaps {
		return d.skin_state.bitmaps[file]
	}
	if file in d.skin_state.failed {
		return none
	}
	data := read_skin_file(&d.skin_state.skin, file) or {
		d.skin_state.failed[file] = true
		return none
	}
	bm := parse_vbm(data) or {
		d.skin_state.failed[file] = true
		return none
	}
	d.skin_state.bitmaps[file] = bm
	return bm
}

fn (mut d Desktop) skin_vector(file string) ?VectorShape {
	if file in d.skin_state.vectors {
		return d.skin_state.vectors[file]
	}
	if file in d.skin_state.failed {
		return none
	}
	data := read_skin_file(&d.skin_state.skin, file) or {
		d.skin_state.failed[file] = true
		return none
	}
	shape := parse_vector(data.bytestr()) or {
		d.skin_state.failed[file] = true
		return none
	}
	d.skin_state.vectors[file] = shape
	return shape
}

fn (mut d Desktop) skin_mask(file string, w int, h int) ?[]u8 {
	key := '${file}@${w}x${h}'
	if key in d.skin_state.masks {
		return d.skin_state.masks[key]
	}
	shape := d.skin_vector(file)?
	if d.skin_state.masks.len >= skin_cache_masks {
		d.skin_state.masks.clear()
	}
	mask := rasterize_vector(shape, w, h)
	d.skin_state.masks[key] = mask
	return mask
}

// draw_drawable paints one of a skin's drawables into a box. `ink` is the colour
// a vector takes when the skin gives it none. It reports whether anything was
// drawn, so a drawable that would not load leaves the caller's own look in place.
fn (mut d Desktop) draw_drawable(dr Drawable, x int, y int, w int, h int, ink u32) bool {
	if w <= 0 || h <= 0 {
		return false
	}
	match dr.kind {
		.none_ {
			return false
		}
		.fill {
			d.canvas.fill_rect(x, y, w, h, dr.color)
			return true
		}
		.bitmap {
			bm := d.skin_bitmap(dr.file) or { return false }
			for j in 0 .. h {
				for i in 0 .. w {
					px := bm.pixels[nine_slice_source(bm, i, j, w, h, dr.slice[0], dr.slice[1],
						dr.slice[2], dr.slice[3])]
					alpha := px >> 24
					if alpha != 0 {
						d.canvas.blend_pixel(x + i, y + j, px & 0xffffff, alpha)
					}
				}
			}
			return true
		}
		.vector {
			mask := d.skin_mask(dr.file, w, h) or { return false }
			color := if dr.has_color { dr.color } else { ink }
			for j in 0 .. h {
				for i in 0 .. w {
					cov := mask[j * w + i]
					if cov != 0 {
						d.canvas.blend_pixel(x + i, y + j, color, u32(cov))
					}
				}
			}
			return true
		}
	}
}

// widget_part is the widget a window-chrome element id names ("close" in
// "win.3.close"), or none for any other element.
fn widget_part(id string) ?string {
	if !id.starts_with('win.') {
		return none
	}
	dot := id.last_index('.') or { return none }
	part := id[dot + 1..]
	if widget_action_from_name(part) == none {
		return none
	}
	return part
}

// draw_skinned_widget paints a window widget from the active skin. It reports
// whether it did; false leaves the stock look to draw.
fn (mut d Desktop) draw_skinned_widget(el &ui2.Element, x int, y int, w int, h int) bool {
	if !d.skin_active() {
		return false
	}
	part := widget_part(el.id) or { return false }
	sw := d.skin_widget(part) or { return false }
	rest := el.id[4..]
	dot := rest.index('.') or { return false }
	window_id := rest[..dot].int()
	hover := d.hover == el.id
	pressed := hover && d.buttons & button_left != 0
	inactive := window_id != d.focus
	dr := sw.state_drawable(hover, pressed, inactive)
	theme := d.theme()
	ink := if inactive { theme.title_text_inactive } else { theme.glyph_color }
	return d.draw_drawable(dr, x, y, w, h, ink)
}

// draw_skinned_bar paints a window's title bar from the active skin.
fn (mut d Desktop) draw_skinned_bar(active bool, x int, y int, w int, h int) bool {
	if !d.skin_active() {
		return false
	}
	skin := &d.skin_state.skin
	mut dr := if active { skin.bar_active } else { skin.bar_inactive }
	if dr.kind == .none_ {
		dr = skin.bar_active
	}
	return d.draw_drawable(dr, x, y, w, h, 0)
}
