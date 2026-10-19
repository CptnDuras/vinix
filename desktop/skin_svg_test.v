module main

fn ink_of(shape VectorShape, w int, h int) int {
	return rasterize_vector(shape, w, h).filter(it > 127).len
}

fn svg_of(body string) string {
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12">${body}</svg>'
}

fn test_a_path_in_a_viewbox_becomes_a_shape() {
	shape := parse_svg_vector(svg_of('<path d="M0 0 H12 V12 H0 Z"/>')) or { panic('not read') }
	assert shape.width == 12 && shape.height == 12
	assert shape.polygons.len == 1
	assert ink_of(shape, 12, 12) == 144
}

fn test_width_and_height_stand_in_for_a_missing_viewbox() {
	shape := parse_svg_vector('<svg width="24px" height="16"><rect width="24" height="16"/></svg>') or {
		panic('not read')
	}
	assert shape.width == 24 && shape.height == 16
	assert parse_svg_vector('<svg><rect width="4" height="4"/></svg>') == none
}

fn test_basic_shapes_fill_what_they_should() {
	rect := parse_svg_vector(svg_of('<rect x="2" y="2" width="8" height="8"/>')) or { panic('rect') }
	assert ink_of(rect, 12, 12) == 64
	round := parse_svg_vector(svg_of('<rect x="0" y="0" width="12" height="12" rx="6"/>')) or { panic('round') }
	n := ink_of(round, 12, 12)
	assert n > 105 && n < 120
	circle := parse_svg_vector(svg_of('<circle cx="6" cy="6" r="6"/>')) or { panic('circle') }
	c := ink_of(circle, 12, 12)
	assert c > 105 && c < 120
	ellipse := parse_svg_vector(svg_of('<ellipse cx="6" cy="6" rx="6" ry="3"/>')) or { panic('ellipse') }
	e := ink_of(ellipse, 12, 12)
	assert e > 48 && e < 60
	poly := parse_svg_vector(svg_of('<polygon points="0,0 12,0 12,12 0,12"/>')) or { panic('polygon') }
	assert ink_of(poly, 12, 12) == 144
	tri := parse_svg_vector(svg_of('<polygon points="6 0 12 12 0 12"/>')) or { panic('triangle') }
	t := ink_of(tri, 12, 12)
	assert t > 60 && t < 84
}

fn test_arcs_are_drawn_including_with_packed_flags() {
	half := parse_svg_vector(svg_of('<path d="M0 6 A6 6 0 0 1 12 6 Z"/>')) or { panic('half') }
	h := ink_of(half, 12, 12)
	assert h > 48 && h < 66
	// The flags run into the numbers, as minified icons write them.
	packed := parse_svg_vector(svg_of('<path d="M0 6a6 6 0 0112 0z"/>')) or { panic('packed') }
	assert ink_of(packed, 12, 12) == h
	// The other sweep is the other half.
	other := parse_svg_vector(svg_of('<path d="M0 6 A6 6 0 0 0 12 6 Z"/>')) or { panic('other') }
	assert ink_of(other, 12, 12) > 48
	// Too small a radius is grown to span the points: still a half circle.
	grown := parse_svg_vector(svg_of('<path d="M0 6 A1 1 0 0 1 12 6 Z"/>')) or { panic('grown') }
	assert ink_of(grown, 12, 12) > 48
}

fn test_transforms_move_shapes_and_groups() {
	moved := parse_svg_vector(svg_of('<rect width="4" height="4" transform="translate(8 8)"/>')) or { panic('translate') }
	assert moved.polygons[0][0].x == 8 && moved.polygons[0][0].y == 8
	scaled := parse_svg_vector(svg_of('<g transform="scale(2)"><rect width="3" height="3"/></g>')) or { panic('scale') }
	assert ink_of(scaled, 12, 12) == 36
	// A group's transform applies to what is inside, with the shape's own inside that.
	both := parse_svg_vector(svg_of('<g transform="translate(6,0)"><rect width="2" height="2" transform="scale(2)"/></g>')) or {
		panic('both')
	}
	assert both.polygons[0][0].x == 6
	assert ink_of(both, 12, 12) == 16
	turned := parse_svg_vector(svg_of('<rect x="0" y="0" width="12" height="6" transform="rotate(90 6 6)"/>')) or { panic('rotate') }
	assert ink_of(turned, 12, 12) == 72
	matrix := parse_svg_vector(svg_of('<rect width="4" height="4" transform="matrix(1 0 0 1 2 3)"/>')) or { panic('matrix') }
	assert matrix.polygons[0][0].x == 2 && matrix.polygons[0][0].y == 3
	// A transform it cannot read makes the file unusable rather than misplaced.
	assert parse_svg_vector(svg_of('<rect width="4" height="4" transform="skewX(10)"/>')) == none
}

fn test_a_viewbox_offset_moves_the_origin() {
	shape := parse_svg_vector('<svg viewBox="10 20 12 12"><rect x="10" y="20" width="12" height="12"/></svg>') or {
		panic('offset')
	}
	assert shape.polygons[0][0].x == 0 && shape.polygons[0][0].y == 0
}

fn test_outlines_and_things_not_drawn_where_they_stand_are_left_out() {
	// Nothing is stroked, so a shape with no fill leaves nothing to draw.
	assert parse_svg_vector(svg_of('<rect width="6" height="6" fill="none" stroke="#000"/>')) == none
	// The root's fill="none" is inherited, as a stroke icon sets it.
	assert parse_svg_vector('<svg viewBox="0 0 12 12" fill="none" stroke="currentColor"><path d="M0 0 H12 V12 Z"/></svg>') == none
	// ...until a shape says otherwise.
	filled := parse_svg_vector('<svg viewBox="0 0 12 12" fill="none"><path d="M0 0 H12 V12 Z" fill="#000"/></svg>') or { panic('fill') }
	assert filled.polygons.len == 1
	// A style attribute can say it too.
	assert parse_svg_vector(svg_of('<rect width="6" height="6" style="fill: none"/>')) == none
	// Definitions are not drawn, comments and declarations are skipped.
	text := '<?xml version="1.0"?><!DOCTYPE svg><!-- <rect width="1" height="1"/> --><svg viewBox="0 0 12 12"><defs><clipPath id="c"><rect width="12" height="12"/></clipPath></defs><rect width="3" height="3"/></svg>'
	shape := parse_svg_vector(text) or { panic('defs') }
	assert shape.polygons.len == 1
	assert ink_of(shape, 12, 12) == 9
	// Tags with a > inside a quoted value still read.
	quoted := parse_svg_vector('<svg viewBox="0 0 12 12"><rect width="3" height="3" data-x="a>b"/></svg>') or { panic('quoted') }
	assert quoted.polygons.len == 1
}

fn test_files_that_are_not_usable_are_refused() {
	assert parse_svg_vector('') == none
	assert parse_svg_vector('not xml at all') == none
	assert parse_svg_vector('<svg viewBox="0 0 0 0"><rect width="1" height="1"/></svg>') == none
	assert parse_svg_vector('<svg viewBox="0 0 12 12"></svg>') == none
	assert parse_svg_vector('<svg viewBox="0 0 12 12"><svg viewBox="0 0 4 4"><rect width="1" height="1"/></svg></svg>') == none
	// A path with a command it does not know is refused whole.
	assert parse_svg_vector(svg_of('<path d="M0 0 X1 1"/>')) == none
	// Far too many points.
	mut many := 'M0 0'
	for i in 0 .. 21000 {
		many += ' L${i % 12} ${(i * 7) % 12}'
	}
	assert parse_svg_vector(svg_of('<path d="${many} Z"/>')) == none
}

fn test_lengths_may_carry_units() {
	assert svg_length('12') or { -1.0 } == 12
	assert svg_length('12px') or { -1.0 } == 12
	assert svg_length('1.5em') or { -1.0 } == 1.5
	assert svg_length('50%') == none
	assert svg_length('') == none
	assert svg_length('ab') == none
}
