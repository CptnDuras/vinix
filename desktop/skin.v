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

import os
import ui2

const skin_default_dir = '/usr/share/vinix/skins'
// The user's own skins, one directory each with a skin.cfg in it. Like the
// desktop's preferences they live under /root, the image's one writable part.
const skin_user_default_dir = '/root/.vinix-skins'
// skin_root is where installed skins live. VINIX_SKIN_DIR moves it, which is how
// the tests and a skin author's own checkout point the desktop at their files.
fn skin_root() string {
	custom := os.getenv('VINIX_SKIN_DIR')
	return if custom.len > 0 { custom } else { skin_default_dir }
}

// skin_user_root is where the user keeps skins of their own. VINIX_USER_SKIN_DIR
// moves it.
fn skin_user_root() string {
	custom := os.getenv('VINIX_USER_SKIN_DIR')
	return if custom.len > 0 { custom } else { skin_user_default_dir }
}

// The most skins read from the user's folder, so a crowded one cannot make the
// picker unusable.
const skin_user_max = 48

// The most a single skin asset may weigh; a window's chrome never needs more.
const skin_asset_max = 2 * 1024 * 1024
const skin_cache_masks = 64

struct SkinEntry {
	id   string
	name string
	// The folder its files are in; empty for a skin compiled into the desktop.
	dir string
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
// installed ones, then the user's own. A missing index or folder only means there
// are none. Later kinds are appended, so a skin that appears while the desktop
// runs does not renumber the ones it already knows.
fn list_skins() []SkinEntry {
	mut out := []SkinEntry{}
	for id in builtin_skin_ids {
		out << SkinEntry{
			id: id
			name: builtin_skin_name(id)
		}
	}
	list_installed_skins(mut out)
	list_user_skins(mut out)
	return out
}

fn skin_listed(entries []SkinEntry, id string) bool {
	return entries.any(it.id == id)
}

fn list_installed_skins(mut out []SkinEntry) {
	index := '${skin_root()}/index.txt'
	info := desktop_stat(index) or { return }
	if info.size == 0 || info.size > 64 * 1024 {
		return
	}
	mut buffer := []u8{len: int(info.size) + 1}
	got := desktop_read_file(index, buffer.data, info.size)
	if got <= 0 {
		return
	}
	text := unsafe { tos(buffer.data, int(got)) }
	for line in text.split_into_lines() {
		trimmed := line.trim_space()
		space := trimmed.index(' ') or { continue }
		id := trimmed[..space]
		if !skin_id_valid(id) || skin_listed(out, id) {
			continue
		}
		out << SkinEntry{
			id: id
			name: trimmed[space + 1..].trim_space()
			dir: '${skin_root()}/${id}'
		}
	}
}

// list_user_skins adds the directories of the user's skin folder that hold a
// skin.cfg, by name, each under the name its skin.cfg gives.
fn list_user_skins(mut out []SkinEntry) {
	dir := desktop_opendir(skin_user_root())
	if dir == unsafe { nil } {
		return
	}
	mut found := []string{}
	mut name := []u8{len: 256}
	for found.len < skin_user_max && desktop_readdir(dir, mut name) {
		id := unsafe { cstring_to_vstring(&char(name.data)) }.clone()
		if skin_id_valid(id) && !skin_listed(out, id) {
			found << id
		}
	}
	desktop_closedir(dir)
	found.sort()
	for id in found {
		cfg := read_skin_cfg('${skin_user_root()}/${id}') or { continue }
		parsed := parse_skin(id, '', cfg)
		out << SkinEntry{
			id: id
			name: parsed.name
			dir: '${skin_user_root()}/${id}'
		}
	}
}

// read_skin_cfg is the skin.cfg of a skin directory, if it has a usable one.
fn read_skin_cfg(dir string) ?string {
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
	return unsafe { tos(buffer.data, int(got)) }.clone()
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
	// The user's own folder first, so a skin of theirs can stand in for an
	// installed one of the same name.
	for root in [skin_user_root(), skin_root()] {
		dir := '${root}/${id}'
		if cfg := read_skin_cfg(dir) {
			return parse_skin(id, dir, cfg)
		}
	}
	return none
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
	return d.theme().window_chrome.skin
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
	// A skin's bitmaps are PNG files or the small VBM1 format of its own.
	bm := (if file.ends_with('.png') { decode_skin_png(data) } else { parse_vbm(data) }) or {
		d.skin_state.failed[file] = true
		return none
	}
	d.skin_state.bitmaps[file] = bm
	return bm
}

// decode_skin_png reads a PNG into a bitmap, for a skin that ships its artwork as
// one. The picture is checked against the size a window's chrome can use, and
// its compressed data against the size it claims, before any pixel is made.
fn decode_skin_png(data []u8) ?Bitmap {
	if data.len < 8 || data[0] != 0x89 || data[1] != `P` || data[2] != `N` || data[3] != `G` {
		return none
	}
	mut width := 0
	mut height := 0
	mut channels := 0
	if C.stbi_info_from_memory(data.data, data.len, &width, &height, &channels) == 0 {
		return none
	}
	if width < 1 || height < 1 || width > vbm_max_side || height > vbm_max_side {
		return none
	}
	if !preview_png_inflate_bounded(data, width, height) {
		return none
	}
	mut dims := [3]int{}
	pixels := C.stbi_load_from_memory(data.data, data.len, unsafe { &dims[0] }, unsafe { &dims[1] },
		unsafe { &dims[2] }, 4)
	if pixels == unsafe { nil } {
		return none
	}
	defer {
		C.stbi_image_free(pixels)
	}
	if dims[0] != width || dims[1] != height {
		return none
	}
	mut out := []u32{len: width * height}
	for i in 0 .. width * height {
		o := i * 4
		unsafe {
			out[i] = u32(pixels[o + 3]) << 24 | u32(pixels[o]) << 16 | u32(pixels[o + 1]) << 8 | u32(pixels[o + 2])
		}
	}
	return Bitmap{
		width: width
		height: height
		pixels: out
	}
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
	// A skin's vectors are SVG files or the path text of its own.
	shape := (if file.ends_with('.svg') {
		parse_svg_vector(data.bytestr())
	} else {
		parse_vector(data.bytestr())
	}) or {
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
		.bevel {
			d.draw_bevel_plate(dr, x, y, w, h, false)
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
	if sw.plate.kind == .bevel {
		if inactive {
			// A control of a window that is not in front is an empty, flat outline.
			d.canvas.fill_rect(x, y, w, h, sw.plate.dark)
			d.canvas.fill_rect(x + 1, y + 1, w - 2, h - 2, sw.plate.color)
			return true
		}
		d.draw_bevel_plate(sw.plate, x, y, w, h, pressed)
		// A held control sinks, and its mark with it. The mark sits inside the
		// plate, a quarter of its side in from each edge.
		margin := w / 4
		nudge := if pressed { 1 } else { 0 }
		d.draw_drawable(dr, x + margin + nudge, y + margin + nudge, w - 2 * margin, h - 2 * margin, ink)
		return true
	}
	return d.draw_drawable(dr, x, y, w, h, ink)
}

// draw_bevel_plate paints a bevelled square: a one-pixel outline, the light and
// dark edges inside it, and the face, shaded top to bottom when the plate has a
// second face colour. Sunken swaps the two edges.
fn (mut d Desktop) draw_bevel_plate(dr Drawable, x int, y int, w int, h int, sunken bool) {
	if w < 4 || h < 4 {
		d.canvas.fill_rect(x, y, w, h, dr.color)
		return
	}
	d.canvas.fill_rect(x, y, w, h, dr.outline)
	inner_x := x + 1
	inner_y := y + 1
	inner_w := w - 2
	inner_h := h - 2
	if dr.face2 != 0 && !sunken {
		d.canvas.vertical_gradient(inner_x, inner_y, inner_w, inner_h, dr.color, dr.face2)
	} else {
		d.canvas.fill_rect(inner_x, inner_y, inner_w, inner_h, dr.color)
	}
	if sunken {
		d.canvas.bevel_rect(inner_x, inner_y, inner_w, inner_h, .raised, 1, dr.dark, dr.light, 0)
	} else {
		d.canvas.bevel_rect(inner_x, inner_y, inner_w, inner_h, .raised, 1, dr.light, dr.dark, 0)
	}
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

// The skins on offer, read once: the application protocol names a skin by its
// place in this list, so the desktop and Settings must see the same one.
struct SkinCatalog {
mut:
	loaded  bool
	entries []SkinEntry
}

__global skin_catalog_cache = SkinCatalog{}

fn skin_catalog() []SkinEntry {
	if !skin_catalog_cache.loaded {
		skin_catalog_cache.entries = list_skins()
		skin_catalog_cache.loaded = true
	}
	return skin_catalog_cache.entries
}

// skin_wire_value carries a skin choice as a small integer: nothing for "follow
// the look", 0 for "no skin", and a skin's place in the catalogue plus one.
fn skin_wire_value(id string) ?int {
	if id.len == 0 {
		return none
	}
	if id == 'none' {
		return 0
	}
	for i, entry in skin_catalog() {
		if entry.id == id {
			return i + 1
		}
	}
	return none
}

fn skin_from_wire(value ?int) string {
	v := value or { return '' }
	if v == 0 {
		return 'none'
	}
	mut entries := skin_catalog()
	if v - 1 >= entries.len {
		// A skin added since the list was read: read it again, once.
		skin_catalog_cache.loaded = false
		entries = skin_catalog()
	}
	if v - 1 < entries.len {
		return entries[v - 1].id
	}
	return ''
}
