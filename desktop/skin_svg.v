// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// SVG for skins: a skin names a control's artwork as `vector:icon.svg` and this
// turns the file into the polygons skin_model.v draws. It is a reader for icons,
// not a renderer for documents, so it keeps to what a control needs:
//
//   * shapes: path, rect (with rx and ry), circle, ellipse, polygon, polyline;
//   * the viewBox, or width and height, for the coordinate space;
//   * transform on a shape or a group: translate, scale, rotate, matrix;
//   * paths with every command, including arcs (skin_model.v's parser).
//
// Everything is filled in one colour, which the skin or the look chooses, with
// the non-zero rule, so fills, strokes, gradients and opacity are not read. A
// shape with fill="none" is left out, as it would have drawn nothing but an
// outline, and so is anything inside <defs>, <clipPath>, <mask>, <symbol>,
// <pattern>, <marker> or <style>.
module main

import math

// svg_max_points bounds the work a hostile or enormous file can cost.
const svg_max_points = 20000
const svg_max_depth = 32

// SvgMatrix is the affine transform [a c e; b d f].
struct SvgMatrix {
	a f64 = 1
	b f64
	c f64
	d f64 = 1
	e f64
	f f64
}

fn (m SvgMatrix) mul(n SvgMatrix) SvgMatrix {
	// m applied after n: the point goes through n first.
	return SvgMatrix{
		a: m.a * n.a + m.c * n.b
		b: m.b * n.a + m.d * n.b
		c: m.a * n.c + m.c * n.d
		d: m.b * n.c + m.d * n.d
		e: m.a * n.e + m.c * n.f + m.e
		f: m.b * n.e + m.d * n.f + m.f
	}
}

fn (m SvgMatrix) apply(p VecPoint) VecPoint {
	return VecPoint{
		x: m.a * p.x + m.c * p.y + m.e
		y: m.b * p.x + m.d * p.y + m.f
	}
}

// svg_numbers reads the numbers in a transform's argument list or a points
// attribute, in either comma or space separated form.
fn svg_numbers(text string) []f64 {
	mut s := PathScanner{
		text: text
	}
	mut out := []f64{}
	for s.at_number() {
		n := s.number() or { break }
		out << n
		if out.len > svg_max_points * 2 {
			break
		}
	}
	return out
}

// svg_transform reads a transform attribute, a list of functions applied left to
// right as SVG defines it (the leftmost is outermost).
fn svg_transform(text string) ?SvgMatrix {
	mut result := SvgMatrix{}
	mut rest := text.trim_space()
	for rest.len > 0 {
		open := rest.index('(') or { return none }
		close := rest.index(')') or { return none }
		if close < open {
			return none
		}
		name := rest[..open].trim_space().trim(', ')
		args := svg_numbers(rest[open + 1..close])
		next := match name {
			'translate' {
				if args.len < 1 || args.len > 2 {
					return none
				}
				SvgMatrix{
					e: args[0]
					f: if args.len == 2 { args[1] } else { 0 }
				}
			}
			'scale' {
				if args.len < 1 || args.len > 2 {
					return none
				}
				SvgMatrix{
					a: args[0]
					d: if args.len == 2 { args[1] } else { args[0] }
				}
			}
			'rotate' {
				if args.len != 1 && args.len != 3 {
					return none
				}
				rad := args[0] * math.pi / 180.0
				cs := math.cos(rad)
				sn := math.sin(rad)
				rot := SvgMatrix{
					a: cs
					b: sn
					c: -sn
					d: cs
				}
				if args.len == 3 {
					// About a point: move it to the origin, turn, move it back.
					SvgMatrix{
						e: args[1]
						f: args[2]
					}.mul(rot).mul(SvgMatrix{
						e: -args[1]
						f: -args[2]
					})
				} else {
					rot
				}
			}
			'matrix' {
				if args.len != 6 {
					return none
				}
				SvgMatrix{
					a: args[0]
					b: args[1]
					c: args[2]
					d: args[3]
					e: args[4]
					f: args[5]
				}
			}
			else {
				return none
			}
		}
		result = result.mul(next)
		rest = rest[close + 1..].trim_space().trim_left(',').trim_space()
	}
	return result
}

// SvgTag is one tag read from the file: its name, whether it closes, whether it
// is self-closing, and its attributes.
struct SvgTag {
mut:
	name    string
	closing bool
	empty   bool
	attrs   map[string]string
}

// svg_next_tag reads the tag starting at or after `from`, skipping comments,
// processing instructions, doctypes and CDATA. It answers the tag and the
// position after it, or none at the end of the text.
fn svg_next_tag(text string, from int) ?(SvgTag, int) {
	mut at := from
	for {
		lt := text.index_after('<', at) or { return none }
		if text[lt..].starts_with('<!--') {
			end := text.index_after('-->', lt + 4) or { return none }
			at = end + 3
			continue
		}
		if text[lt..].starts_with('<![CDATA[') {
			end := text.index_after(']]>', lt + 9) or { return none }
			at = end + 3
			continue
		}
		if lt + 1 < text.len && (text[lt + 1] == `?` || text[lt + 1] == `!`) {
			end := text.index_after('>', lt) or { return none }
			at = end + 1
			continue
		}
		// The tag ends at the first > outside a quoted value.
		mut i := lt + 1
		mut quote := u8(0)
		for i < text.len {
			c := text[i]
			if quote != 0 {
				if c == quote {
					quote = 0
				}
			} else if c == `"` || c == `'` {
				quote = c
			} else if c == `>` {
				break
			}
			i++
		}
		if i >= text.len {
			return none
		}
		return svg_parse_tag(text[lt + 1..i]), i + 1
	}
	return none
}

fn svg_parse_tag(body string) SvgTag {
	mut tag := SvgTag{}
	mut b := body.trim_space()
	if b.starts_with('/') {
		tag.closing = true
		b = b[1..].trim_space()
	}
	if b.ends_with('/') {
		tag.empty = true
		b = b[..b.len - 1].trim_space()
	}
	mut i := 0
	for i < b.len && b[i] != ` ` && b[i] != `\t` && b[i] != `\n` && b[i] != `\r` {
		i++
	}
	tag.name = b[..i].to_lower()
	// Namespaced names, as in svg:path, are the part after the colon.
	if colon := tag.name.index(':') {
		tag.name = tag.name[colon + 1..]
	}
	for i < b.len {
		for i < b.len && (b[i] == ` ` || b[i] == `\t` || b[i] == `\n` || b[i] == `\r`) {
			i++
		}
		start := i
		for i < b.len && b[i] != `=` && b[i] != ` ` && b[i] != `\t` && b[i] != `\n` && b[i] != `\r` {
			i++
		}
		key := b[start..i]
		for i < b.len && (b[i] == ` ` || b[i] == `\t` || b[i] == `\n` || b[i] == `\r`) {
			i++
		}
		if i >= b.len || b[i] != `=` {
			continue
		}
		i++
		for i < b.len && (b[i] == ` ` || b[i] == `\t` || b[i] == `\n` || b[i] == `\r`) {
			i++
		}
		if i >= b.len {
			break
		}
		q := b[i]
		if q != `"` && q != `'` {
			continue
		}
		i++
		vstart := i
		for i < b.len && b[i] != q {
			i++
		}
		if key.len > 0 {
			tag.attrs[key.to_lower()] = b[vstart..i]
		}
		i++
	}
	return tag
}

// svg_length reads a number with an optional unit as user units; percentages and
// other relative units are not meaningful here.
fn svg_length(text string) ?f64 {
	t := text.trim_space()
	if t.len == 0 || t.ends_with('%') {
		return none
	}
	mut end := t.len
	for end > 0 && ((t[end - 1] >= `a` && t[end - 1] <= `z`) || (t[end - 1] >= `A` && t[end - 1] <= `Z`)) {
		end--
	}
	mut s := PathScanner{
		text: t[..end]
	}
	n := s.number() or { return none }
	s.skip_separators()
	if s.pos != s.text.len {
		return none
	}
	return n
}

fn svg_attr_f(tag SvgTag, name string, default f64) f64 {
	return svg_length(tag.attrs[name] or { return default }) or { default }
}

// svg_shape_path is the path data of a basic shape, or none for a tag that is not
// a filled shape.
fn svg_shape_path(tag SvgTag) ?string {
	match tag.name {
		'path' {
			return tag.attrs['d'] or { return none }
		}
		'rect' {
			x := svg_attr_f(tag, 'x', 0)
			y := svg_attr_f(tag, 'y', 0)
			w := svg_attr_f(tag, 'width', 0)
			h := svg_attr_f(tag, 'height', 0)
			if w <= 0 || h <= 0 {
				return none
			}
			mut rx := svg_attr_f(tag, 'rx', -1)
			mut ry := svg_attr_f(tag, 'ry', -1)
			if rx < 0 && ry < 0 {
				rx = 0
				ry = 0
			} else if rx < 0 {
				rx = ry
			} else if ry < 0 {
				ry = rx
			}
			rx = math.min(rx, w / 2)
			ry = math.min(ry, h / 2)
			if rx <= 0 || ry <= 0 {
				return 'M${x} ${y} H${x + w} V${y + h} H${x} Z'
			}
			return 'M${x + rx} ${y} H${x + w - rx} A${rx} ${ry} 0 0 1 ${x + w} ${y + ry} V${y + h - ry} A${rx} ${ry} 0 0 1 ${x + w - rx} ${y + h} H${x + rx} A${rx} ${ry} 0 0 1 ${x} ${y + h - ry} V${y + ry} A${rx} ${ry} 0 0 1 ${x + rx} ${y} Z'
		}
		'circle', 'ellipse' {
			cx := svg_attr_f(tag, 'cx', 0)
			cy := svg_attr_f(tag, 'cy', 0)
			mut rx := svg_attr_f(tag, 'rx', 0)
			mut ry := svg_attr_f(tag, 'ry', 0)
			if tag.name == 'circle' {
				rx = svg_attr_f(tag, 'r', 0)
				ry = rx
			}
			if rx <= 0 || ry <= 0 {
				return none
			}
			return 'M${cx - rx} ${cy} A${rx} ${ry} 0 1 0 ${cx + rx} ${cy} A${rx} ${ry} 0 1 0 ${cx - rx} ${cy} Z'
		}
		'polygon', 'polyline' {
			nums := svg_numbers(tag.attrs['points'] or { return none })
			if nums.len < 6 || nums.len % 2 != 0 {
				return none
			}
			mut d := 'M${nums[0]} ${nums[1]}'
			for i := 2; i < nums.len; i += 2 {
				d += ' L${nums[i]} ${nums[i + 1]}'
			}
			return d + ' Z'
		}
		else {
			return none
		}
	}
}

// svg_fill_none is whether a tag's fill says nothing is painted, taking what its
// group said when it names none of its own. The style attribute can say it too.
fn svg_fill_none(tag SvgTag, inherited bool) bool {
	if style := tag.attrs['style'] {
		compact := style.replace(' ', '').to_lower()
		if compact.contains('fill:none') || compact.contains('fill:transparent') {
			return true
		}
	}
	fill := (tag.attrs['fill'] or { return inherited }).trim_space().to_lower()
	return fill == 'none' || fill == 'transparent'
}

// svg_skipped tags hold things that are not drawn where they stand.
fn svg_skipped(name string) bool {
	return name in ['defs', 'clippath', 'mask', 'symbol', 'pattern', 'marker', 'style', 'script', 'metadata', 'title', 'desc', 'filter', 'lineargradient', 'radialgradient']
}

// parse_svg_vector reads an SVG icon into a shape in the file's own coordinates,
// moved so that its viewBox starts at the origin. It answers none for a file
// that is not an SVG, has no usable size, or draws nothing it can fill.
fn parse_svg_vector(text string) ?VectorShape {
	if text.len == 0 || text.len > 512 * 1024 {
		return none
	}
	mut shape := VectorShape{}
	mut view_x := 0.0
	mut view_y := 0.0
	mut seen_svg := false
	mut stack := []SvgMatrix{}
	mut skip_depth := 0
	mut open_names := []string{}
	mut at := 0
	mut points := 0
	mut nones := []bool{} // fill="none" in force, per open group, as the stack
	for {
		tag, next := svg_next_tag(text, at) or { break }
		at = next
		if tag.closing {
			if open_names.len > 0 && open_names.last() == tag.name {
				open_names.delete_last()
				if skip_depth > 0 && svg_skipped(tag.name) {
					skip_depth--
				}
				if stack.len > 0 && tag.name in ['g', 'svg', 'a'] {
					stack.delete_last()
					nones.delete_last()
				}
			}
			continue
		}
		if !tag.empty {
			if open_names.len >= svg_max_depth {
				return none
			}
			open_names << tag.name
		}
		if svg_skipped(tag.name) {
			if !tag.empty {
				skip_depth++
			}
			continue
		}
		if skip_depth > 0 {
			continue
		}
		// The matrix in force: the enclosing groups' product with this tag's own.
		mut matrix := if stack.len > 0 { stack.last() } else { SvgMatrix{} }
		if t := tag.attrs['transform'] {
			own := svg_transform(t) or { return none }
			matrix = matrix.mul(own)
		}
		if tag.name == 'svg' {
			if seen_svg {
				// A nested <svg> is a viewport of its own; icons do not use it.
				return none
			}
			seen_svg = true
			if vb := tag.attrs['viewbox'] {
				nums := svg_numbers(vb)
				if nums.len != 4 || nums[2] <= 0 || nums[3] <= 0 {
					return none
				}
				view_x = nums[0]
				view_y = nums[1]
				shape.width = nums[2]
				shape.height = nums[3]
			} else {
				w := svg_length(tag.attrs['width'] or { '' }) or { 0 }
				h := svg_length(tag.attrs['height'] or { '' }) or { 0 }
				if w <= 0 || h <= 0 {
					return none
				}
				shape.width = w
				shape.height = h
			}
			if !tag.empty {
				stack << SvgMatrix{}
				nones << svg_fill_none(tag, false)
			}
			continue
		}
		if !seen_svg {
			continue
		}
		inherited_none := nones.len > 0 && nones.last()
		if tag.name == 'g' || tag.name == 'a' {
			if !tag.empty {
				stack << matrix
				nones << svg_fill_none(tag, inherited_none)
			}
			continue
		}
		if svg_fill_none(tag, inherited_none) {
			continue
		}
		d := svg_shape_path(tag) or { continue }
		mut piece := VectorShape{}
		parse_path_data(d, mut piece) or { return none }
		for poly in piece.polygons {
			points += poly.len
			if points > svg_max_points {
				return none
			}
			mut moved := []VecPoint{cap: poly.len}
			for p in poly {
				q := matrix.apply(p)
				moved << VecPoint{
					x: q.x - view_x
					y: q.y - view_y
				}
			}
			shape.polygons << moved
		}
	}
	if !seen_svg || shape.polygons.len == 0 {
		return none
	}
	return shape
}
