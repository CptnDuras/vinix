// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Skins (Blue spec B5, blue-specs/window-chrome.md): vector shapes, bitmaps and
// the file that names them. Pure data and arithmetic, with no ui2 and no file
// access, so every rule here is tested without a desktop.
//
// Vinix has no PNG or SVG decoder, so a skin's art arrives in two small
// formats of its own, in the way wallpapers do (wallpaper.v):
//
//   * a vector is a path in the SVG path syntax, restricted to straight lines
//     and Bezier curves (M L H V C S Q T Z, absolute and relative);
//   * a bitmap is "VBM1", two little-endian u16 for width and height, one
//     reserved byte, then RGBA. desktop/tools/png2vbm.py makes one from a PNG.
module main

import math

// ── Vectors ────────────────────────────────────────────────────────

struct VecPoint {
	x f64
	y f64
}

// VectorShape is a set of closed polygons in a viewBox. Curves are flattened
// when the path is parsed, so rasterising only ever sees straight edges.
struct VectorShape {
mut:
	width    f64
	height   f64
	polygons [][]VecPoint
}

// parse_vector reads the text form of a vector asset:
//
//   viewbox <width> <height>
//   path <svg path data>
//   path <svg path data>
//
// Every path is filled with the non-zero rule, and the paths are unioned.
fn parse_vector(text string) ?VectorShape {
	mut shape := VectorShape{}
	for raw in text.split('\n') {
		line := raw.trim_space()
		if line.starts_with('viewbox ') {
			parts := line[8..].trim_space().split(' ').filter(it.len > 0)
			if parts.len != 2 {
				return none
			}
			shape.width = parts[0].f64()
			shape.height = parts[1].f64()
		} else if line.starts_with('path ') {
			parse_path_data(line[5..], mut shape) or { return none }
		}
	}
	if shape.width <= 0 || shape.height <= 0 || shape.polygons.len == 0 {
		return none
	}
	return shape
}

struct PathScanner {
	text string
mut:
	pos int
}

fn (mut s PathScanner) skip_separators() {
	for s.pos < s.text.len && (s.text[s.pos] == ` ` || s.text[s.pos] == `,`
		|| s.text[s.pos] == `\t` || s.text[s.pos] == `\r` || s.text[s.pos] == `\n`) {
		s.pos++
	}
}

fn (mut s PathScanner) at_number() bool {
	s.skip_separators()
	if s.pos >= s.text.len {
		return false
	}
	c := s.text[s.pos]
	return (c >= `0` && c <= `9`) || c == `-` || c == `+` || c == `.`
}

fn (mut s PathScanner) number() ?f64 {
	s.skip_separators()
	start := s.pos
	if s.pos < s.text.len && (s.text[s.pos] == `-` || s.text[s.pos] == `+`) {
		s.pos++
	}
	mut seen_dot := false
	for s.pos < s.text.len {
		c := s.text[s.pos]
		if c >= `0` && c <= `9` {
			s.pos++
		} else if c == `.` && !seen_dot {
			seen_dot = true
			s.pos++
		} else {
			break
		}
	}
	if s.pos == start {
		return none
	}
	// An exponent, as in 1e-3.
	if s.pos < s.text.len && (s.text[s.pos] == `e` || s.text[s.pos] == `E`) {
		s.pos++
		if s.pos < s.text.len && (s.text[s.pos] == `-` || s.text[s.pos] == `+`) {
			s.pos++
		}
		for s.pos < s.text.len && s.text[s.pos] >= `0` && s.text[s.pos] <= `9` {
			s.pos++
		}
	}
	return s.text[start..s.pos].f64()
}

const curve_steps = 12

fn flatten_cubic(mut out []VecPoint, p0 VecPoint, p1 VecPoint, p2 VecPoint, p3 VecPoint) {
	for i in 1 .. curve_steps + 1 {
		t := f64(i) / f64(curve_steps)
		u := 1.0 - t
		out << VecPoint{
			x: u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x
			y: u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
		}
	}
}

fn flatten_quad(mut out []VecPoint, p0 VecPoint, p1 VecPoint, p2 VecPoint) {
	for i in 1 .. curve_steps + 1 {
		t := f64(i) / f64(curve_steps)
		u := 1.0 - t
		out << VecPoint{
			x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x
			y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
		}
	}
}

// parse_path_data appends the polygons of one SVG path to the shape. Anything
// the syntax does not allow, including the arc command, makes the path
// unusable rather than approximate.
fn parse_path_data(data string, mut shape VectorShape) ? {
	mut s := PathScanner{
		text: data
	}
	mut current := []VecPoint{}
	mut cur := VecPoint{}
	mut start := VecPoint{}
	mut last_cubic_ctrl := VecPoint{}
	mut last_quad_ctrl := VecPoint{}
	mut prev_cmd := u8(0)
	mut cmd := u8(0)
	for {
		s.skip_separators()
		if s.pos >= s.text.len {
			break
		}
		c := s.text[s.pos]
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) {
			cmd = c
			s.pos++
		} else if cmd == 0 {
			return none
		} else if cmd == `M` {
			cmd = `L`
		} else if cmd == `m` {
			cmd = `l`
		}
		rel := cmd >= `a` && cmd <= `z`
		match cmd {
			`M`, `m` {
				if current.len > 2 {
					shape.polygons << current
				}
				x := s.number()?
				y := s.number()?
				cur = if rel { VecPoint{ x: cur.x + x, y: cur.y + y } } else { VecPoint{ x: x, y: y } }
				start = cur
				current = [cur]
			}
			`L`, `l` {
				x := s.number()?
				y := s.number()?
				cur = if rel { VecPoint{ x: cur.x + x, y: cur.y + y } } else { VecPoint{ x: x, y: y } }
				current << cur
			}
			`H`, `h` {
				x := s.number()?
				cur = VecPoint{
					x: if rel { cur.x + x } else { x }
					y: cur.y
				}
				current << cur
			}
			`V`, `v` {
				y := s.number()?
				cur = VecPoint{
					x: cur.x
					y: if rel { cur.y + y } else { y }
				}
				current << cur
			}
			`C`, `c`, `S`, `s` {
				mut p1 := VecPoint{}
				if cmd == `C` || cmd == `c` {
					x1 := s.number()?
					y1 := s.number()?
					p1 = if rel { VecPoint{ x: cur.x + x1, y: cur.y + y1 } } else { VecPoint{ x: x1, y: y1 } }
				} else {
					// The first control point reflects the previous curve's second.
					p1 = if prev_cmd in [`C`, `c`, `S`, `s`] {
						VecPoint{ x: 2 * cur.x - last_cubic_ctrl.x, y: 2 * cur.y - last_cubic_ctrl.y }
					} else {
						cur
					}
				}
				x2 := s.number()?
				y2 := s.number()?
				x := s.number()?
				y := s.number()?
				p2 := if rel { VecPoint{ x: cur.x + x2, y: cur.y + y2 } } else { VecPoint{ x: x2, y: y2 } }
				p3 := if rel { VecPoint{ x: cur.x + x, y: cur.y + y } } else { VecPoint{ x: x, y: y } }
				flatten_cubic(mut current, cur, p1, p2, p3)
				last_cubic_ctrl = p2
				cur = p3
			}
			`Q`, `q`, `T`, `t` {
				mut p1 := VecPoint{}
				if cmd == `Q` || cmd == `q` {
					x1 := s.number()?
					y1 := s.number()?
					p1 = if rel { VecPoint{ x: cur.x + x1, y: cur.y + y1 } } else { VecPoint{ x: x1, y: y1 } }
				} else {
					p1 = if prev_cmd in [`Q`, `q`, `T`, `t`] {
						VecPoint{ x: 2 * cur.x - last_quad_ctrl.x, y: 2 * cur.y - last_quad_ctrl.y }
					} else {
						cur
					}
				}
				x := s.number()?
				y := s.number()?
				p2 := if rel { VecPoint{ x: cur.x + x, y: cur.y + y } } else { VecPoint{ x: x, y: y } }
				flatten_quad(mut current, cur, p1, p2)
				last_quad_ctrl = p1
				cur = p2
			}
			`Z`, `z` {
				if current.len > 2 {
					shape.polygons << current
				}
				cur = start
				current = [cur]
			}
			else {
				return none
			}
		}
		prev_cmd = cmd
	}
	if current.len > 2 {
		shape.polygons << current
	}
}

// rasterize_vector fills a shape into a w by h coverage mask, 0..255 per pixel.
// Each pixel is sampled at four heights and its horizontal coverage is exact,
// which is plenty for controls a few dozen pixels across.
fn rasterize_vector(shape VectorShape, w int, h int) []u8 {
	mut mask := []u8{len: w * h}
	if w <= 0 || h <= 0 || shape.width <= 0 || shape.height <= 0 {
		return mask
	}
	sx := f64(w) / shape.width
	sy := f64(h) / shape.height
	// Edges, scaled into pixels, with the direction each crosses a scanline.
	mut ex0 := []f64{}
	mut ey0 := []f64{}
	mut ex1 := []f64{}
	mut ey1 := []f64{}
	for poly in shape.polygons {
		for i in 0 .. poly.len {
			a := poly[i]
			b := poly[(i + 1) % poly.len]
			ex0 << a.x * sx
			ey0 << a.y * sy
			ex1 << b.x * sx
			ey1 << b.y * sy
		}
	}
	samples := 4
	mut acc := []f64{len: w}
	mut xs := []f64{}
	mut dirs := []int{}
	for row in 0 .. h {
		for i in 0 .. w {
			acc[i] = 0
		}
		for k in 0 .. samples {
			y := f64(row) + (f64(k) + 0.5) / f64(samples)
			xs.clear()
			dirs.clear()
			for e in 0 .. ex0.len {
				y0 := ey0[e]
				y1 := ey1[e]
				if y0 == y1 {
					continue
				}
				up := y0 < y1
				lo := if up { y0 } else { y1 }
				hi := if up { y1 } else { y0 }
				if y < lo || y >= hi {
					continue
				}
				t := (y - y0) / (y1 - y0)
				x := ex0[e] + t * (ex1[e] - ex0[e])
				// Insertion sort: there are a handful of crossings per scanline.
				mut at := xs.len
				for at > 0 && xs[at - 1] > x {
					at--
				}
				xs.insert(at, x)
				dirs.insert(at, if up { 1 } else { -1 })
			}
			mut winding := 0
			for i in 0 .. xs.len {
				winding += dirs[i]
				if winding == 0 || i + 1 >= xs.len {
					continue
				}
				span_start := math.max(xs[i], 0.0)
				span_end := math.min(xs[i + 1], f64(w))
				if span_end <= span_start {
					continue
				}
				first := int(span_start)
				last := int(math.min(span_end, f64(w) - 0.000001))
				for px in first .. last + 1 {
					left := math.max(span_start, f64(px))
					right := math.min(span_end, f64(px + 1))
					if right > left {
						acc[px] += (right - left) / f64(samples)
					}
				}
			}
		}
		for i in 0 .. w {
			v := acc[i] * 255.0 + 0.5
			mask[row * w + i] = if v >= 255 { u8(255) } else { u8(v) }
		}
	}
	return mask
}

// ── Bitmaps ────────────────────────────────────────────────────────

const vbm_magic = 'VBM1'
const vbm_header_size = 9
// A decoded skin bitmap never needs to be bigger than a window's chrome.
const vbm_max_side = 1024

struct Bitmap {
	width  int
	height int
	// 0xAARRGGBB, not premultiplied.
	pixels []u32
}

// parse_vbm decodes a VBM1 file, or answers none when it is not one or is
// truncated or oversized.
fn parse_vbm(data []u8) ?Bitmap {
	if data.len < vbm_header_size || data[0] != `V` || data[1] != `B` || data[2] != `M`
		|| data[3] != `1` {
		return none
	}
	w := int(data[4]) | int(data[5]) << 8
	h := int(data[6]) | int(data[7]) << 8
	if w < 1 || h < 1 || w > vbm_max_side || h > vbm_max_side {
		return none
	}
	if data.len < vbm_header_size + w * h * 4 {
		return none
	}
	mut pixels := []u32{len: w * h}
	for i in 0 .. w * h {
		o := vbm_header_size + i * 4
		pixels[i] = u32(data[o + 3]) << 24 | u32(data[o]) << 16 | u32(data[o + 1]) << 8 | u32(data[o + 2])
	}
	return Bitmap{
		width: w
		height: h
		pixels: pixels
	}
}

// slice_axis maps a destination coordinate to a source coordinate along one
// axis of a nine-slice: the first `lead` pixels and the last `trail` pixels are
// copied as they are and the middle is stretched. When the destination is too
// small to hold both edges they share it in proportion.
fn slice_axis(d int, dst_len int, src_len int, lead int, trail int) int {
	mut a := lead
	mut b := trail
	if a + b > dst_len && a + b > 0 {
		a = dst_len * lead / (lead + trail)
		b = dst_len - a
	}
	if d < a {
		return if a == 0 { 0 } else { d * lead / a }
	}
	if d >= dst_len - b {
		t := dst_len - d // 1..b
		return src_len - (if b == 0 { 0 } else { t * trail / b })
	}
	mid_dst := dst_len - a - b
	mid_src := src_len - lead - trail
	if mid_dst <= 0 || mid_src <= 0 {
		return clamp_int(lead, 0, src_len - 1)
	}
	return lead + (d - a) * mid_src / mid_dst
}

fn clamp_int(v int, lo int, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// nine_slice_source is the source pixel a destination pixel takes its colour
// from, as an index into the bitmap's pixels.
fn nine_slice_source(bm Bitmap, dx int, dy int, dw int, dh int, left int, top int, right int, bottom int) int {
	sx := clamp_int(slice_axis(dx, dw, bm.width, left, right), 0, bm.width - 1)
	sy := clamp_int(slice_axis(dy, dh, bm.height, top, bottom), 0, bm.height - 1)
	return sy * bm.width + sx
}

// ── Skin files ─────────────────────────────────────────────────────

enum DrawKind {
	none_
	fill
	bitmap
	vector
}

// Drawable is one thing a skin can paint: a flat colour, a bitmap (stretched as
// a nine-slice) or a vector (filled in a colour, which defaults to the
// widget's glyph colour).
struct Drawable {
	kind DrawKind
	file string
	// left, top, right, bottom edges that are not stretched, for bitmaps.
	slice     [4]int
	color     u32
	has_color bool
}

struct SkinWidget {
mut:
	normal   Drawable
	hover    Drawable
	pressed  Drawable
	inactive Drawable
	size     int
}

struct Skin {
mut:
	id          string
	name        string
	dir         string
	chrome      ChromeSpec
	has_chrome  bool
	bar_active  Drawable
	bar_inactive Drawable
	widgets     map[string]SkinWidget
	problems    []string
}

// parse_drawable reads "fill:#rrggbb", "bitmap:<file>[:l,t,r,b]" or
// "vector:<file>[:#rrggbb]".
fn parse_drawable(text string) ?Drawable {
	v := text.trim_space()
	parts := v.split(':')
	if parts.len < 2 {
		return none
	}
	match parts[0] {
		'fill' {
			c := parse_hex_color(parts[1]) or { return none }
			return Drawable{
				kind: .fill
				color: c
				has_color: true
			}
		}
		'bitmap' {
			if parts[1].len == 0 {
				return none
			}
			mut slice := [4]int{}
			if parts.len >= 3 {
				nums := parts[2].split(',')
				if nums.len != 4 {
					return none
				}
				for i in 0 .. 4 {
					n := nums[i].trim_space()
					if n.len == 0 || !n.bytes().all(it >= `0` && it <= `9`) {
						return none
					}
					slice[i] = n.int()
				}
			}
			return Drawable{
				kind: .bitmap
				file: parts[1]
				slice: slice
			}
		}
		'vector' {
			if parts[1].len == 0 {
				return none
			}
			mut d := Drawable{
				kind: .vector
				file: parts[1]
			}
			if parts.len >= 3 {
				c := parse_hex_color(parts[2]) or { return none }
				d = Drawable{
					...d
					color: c
					has_color: true
				}
			}
			return d
		}
		else {
			return none
		}
	}
}

fn parse_hex_color(text string) ?u32 {
	t := text.trim_space()
	if t.len != 7 || t[0] != `#` {
		return none
	}
	mut v := u32(0)
	for i in 1 .. 7 {
		c := t[i]
		d := if c >= `0` && c <= `9` {
			u32(c - `0`)
		} else if c >= `a` && c <= `f` {
			u32(c - `a` + 10)
		} else if c >= `A` && c <= `F` {
			u32(c - `A` + 10)
		} else {
			return none
		}
		v = v << 4 | d
	}
	return v
}

// Skin ids name a directory, so they are kept to a safe alphabet.
fn skin_id_valid(id string) bool {
	if id.len == 0 || id.len > 32 {
		return false
	}
	for c in id {
		if !((c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `-` || c == `_`) {
			return false
		}
	}
	return true
}

// A skin file is a small file; reading more than this means it is not one.
const skin_cfg_max = 16384

// parse_skin reads a skin.cfg. Lines are `key=value`; unknown keys and
// malformed values are recorded in `problems` and skipped, so a skin with one
// bad line still gives the rest of its art.
fn parse_skin(id string, dir string, text string) Skin {
	mut skin := Skin{
		id: id
		dir: dir
	}
	if text.len > skin_cfg_max {
		skin.problems << 'skin.cfg is too large'
		return skin
	}
	for raw in text.split('\n') {
		line := raw.trim_space()
		if line.len == 0 || line[0] == `#` {
			continue
		}
		eq := line.index('=') or {
			skin.problems << 'no "=" in: ${line}'
			continue
		}
		key := line[..eq].trim_space()
		value := line[eq + 1..].trim_space()
		if key == 'name' {
			skin.name = value
		} else if key == 'bar.active' || key == 'bar.inactive' {
			d := parse_drawable(value) or {
				skin.problems << 'bad drawable for ${key}'
				continue
			}
			if key == 'bar.active' {
				skin.bar_active = d
			} else {
				skin.bar_inactive = d
			}
		} else if key.starts_with('widget.') {
			skin.apply_widget_key(key[7..], value)
		} else if key.starts_with('chrome.') {
			if chrome_apply_key(mut skin.chrome, key[7..], value) {
				skin.has_chrome = true
			} else {
				skin.problems << 'bad chrome setting ${key}'
			}
		} else {
			skin.problems << 'unknown key ${key}'
		}
	}
	if skin.name.len == 0 {
		skin.name = id
	}
	return skin
}

// apply_widget_key handles `widget.<action>[.<state>]` and
// `widget.<action>.size`.
fn (mut skin Skin) apply_widget_key(rest string, value string) {
	parts := rest.split('.')
	if parts.len == 0 || parts.len > 2 || widget_action_from_name(parts[0]) == none {
		skin.problems << 'bad widget key ${rest}'
		return
	}
	action := parts[0]
	mut w := skin.widgets[action] or { SkinWidget{} }
	state := if parts.len == 2 { parts[1] } else { 'all' }
	if state == 'size' {
		n := value.int()
		if n < 6 || n > 64 {
			skin.problems << 'bad widget size ${n}'
			return
		}
		w.size = n
		skin.widgets[action] = w
		return
	}
	d := parse_drawable(value) or {
		skin.problems << 'bad drawable for widget.${rest}'
		return
	}
	match state {
		'all' {
			w.normal = d
			w.hover = d
			w.pressed = d
			w.inactive = d
		}
		'normal' { w.normal = d }
		'hover' { w.hover = d }
		'pressed' { w.pressed = d }
		'inactive' { w.inactive = d }
		else {
			skin.problems << 'bad widget state ${state}'
			return
		}
	}
	skin.widgets[action] = w
}

// state_drawable picks the drawable for a widget's state, falling back from a
// state that names nothing to the normal one.
fn (w SkinWidget) state_drawable(hover bool, pressed bool, inactive bool) Drawable {
	if inactive && w.inactive.kind != .none_ {
		return w.inactive
	}
	if pressed && w.pressed.kind != .none_ {
		return w.pressed
	}
	if hover && w.hover.kind != .none_ {
		return w.hover
	}
	return w.normal
}
