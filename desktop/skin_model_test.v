module main

fn test_a_square_path_fills_its_box_and_nothing_outside_it() {
	shape := parse_vector('viewbox 10 10\npath M2 2 H8 V8 H2 Z') or { panic('parse') }
	mask := rasterize_vector(shape, 10, 10)
	assert mask[5 * 10 + 5] == 255
	assert mask[2 * 10 + 2] == 255
	assert mask[0] == 0
	assert mask[9 * 10 + 9] == 0
	assert mask[5 * 10 + 8] == 0
}

fn test_a_shape_scales_to_the_size_it_is_drawn_at() {
	shape := parse_vector('viewbox 10 10\npath M0 0 H10 V10 H0 Z') or { panic('parse') }
	small := rasterize_vector(shape, 4, 4)
	big := rasterize_vector(shape, 20, 20)
	for v in small {
		assert v == 255
	}
	for v in big {
		assert v == 255
	}
}

fn test_a_diagonal_edge_has_partial_coverage() {
	shape := parse_vector('viewbox 8 8\npath M0 0 L8 0 L0 8 Z') or { panic('parse') }
	mask := rasterize_vector(shape, 8, 8)
	// Wholly inside, wholly outside, and on the edge.
	assert mask[0] == 255
	assert mask[7 * 8 + 7] == 0
	on_edge := mask[3 * 8 + 4]
	assert on_edge > 0 && on_edge < 255
}

fn test_curves_relative_commands_and_holes() {
	// A ring: the inner circle runs the other way, so non-zero winding cuts it out.
	ring := parse_vector('viewbox 20 20\npath M10 0 C15.5 0 20 4.5 20 10 S15.5 20 10 20 S0 15.5 0 10 S4.5 0 10 0 Z M10 5 C7.2 5 5 7.2 5 10 S7.2 15 10 15 S15 12.8 15 10 S12.8 5 10 5 Z') or { panic('parse') }
	mask := rasterize_vector(ring, 20, 20)
	assert mask[10 * 20 + 2] > 200 // the band
	assert mask[10 * 20 + 10] < 40 // the hole
	rel := parse_vector('viewbox 10 10\npath m1 1 h8 v8 h-8 z') or { panic('parse') }
	m := rasterize_vector(rel, 10, 10)
	assert m[5 * 10 + 5] == 255 && m[0] == 0
}

fn test_unsupported_or_broken_paths_are_refused() {
	assert parse_vector('viewbox 10 10\npath M0 0 A5 5 0 0 1 10 10 Z') == none
	assert parse_vector('viewbox 10 10\npath M0 0 L') == none
	assert parse_vector('path M0 0 L1 1 L0 1 Z') == none
	assert parse_vector('viewbox 0 10\npath M0 0 L1 1 L0 1 Z') == none
}

fn vbm(w int, h int, rgba []u8) []u8 {
	mut out := [u8(`V`), `B`, `M`, `1`, u8(w & 255), u8(w >> 8), u8(h & 255), u8(h >> 8), 0]
	out << rgba
	return out
}

fn test_vbm_decodes_and_rejects_bad_files() {
	bm := parse_vbm(vbm(2, 1, [u8(255), 0, 0, 255, 0, 0, 255, 128])) or { panic('decode') }
	assert bm.width == 2 && bm.height == 1
	assert bm.pixels[0] == 0xffff0000
	assert bm.pixels[1] == 0x800000ff
	assert parse_vbm(vbm(2, 2, [u8(0), 0, 0, 0])) == none // truncated
	assert parse_vbm([u8(`X`), `B`, `M`, `1`, 1, 0, 1, 0, 0, 0, 0, 0, 0]) == none
	assert parse_vbm(vbm(0, 1, [])) == none
	assert parse_vbm([]u8{}) == none
}

fn test_nine_slice_keeps_corners_and_stretches_the_middle() {
	// 6 wide: columns 0,1 are the left edge, 4,5 the right, 2..3 the middle.
	bm := Bitmap{
		width: 6
		height: 1
		pixels: [u32(0xff000010), 0xff000011, 0xff000012, 0xff000013, 0xff000014, 0xff000015]
	}
	// Drawn 12 wide: the edges are copied, so the ends are the same.
	assert bm.pixels[nine_slice_source(bm, 0, 0, 12, 1, 2, 0, 2, 0)] == 0xff000010
	assert bm.pixels[nine_slice_source(bm, 1, 0, 12, 1, 2, 0, 2, 0)] == 0xff000011
	assert bm.pixels[nine_slice_source(bm, 10, 0, 12, 1, 2, 0, 2, 0)] == 0xff000014
	assert bm.pixels[nine_slice_source(bm, 11, 0, 12, 1, 2, 0, 2, 0)] == 0xff000015
	// The middle comes from the middle columns.
	for x in 2 .. 10 {
		src := nine_slice_source(bm, x, 0, 12, 1, 2, 0, 2, 0)
		assert src >= 2 && src <= 3
	}
	// Drawn smaller than its edges: still in range and symmetric.
	for x in 0 .. 3 {
		assert nine_slice_source(bm, x, 0, 3, 1, 2, 0, 2, 0) < 6
	}
}

fn test_skin_files_parse_widgets_chrome_and_report_bad_lines() {
	text := '# a skin\nname=Tested\nbar.active=bitmap:bar.vbm:4,4,4,4\nbar.inactive=fill:#cccccc\nwidget.close=vector:x.vec:#ff0000\nwidget.close.hover=vector:xh.vec\nwidget.maximize.size=14\nchrome.kind=tab\nchrome.tab_align=right\nchrome.widgets=close@leading,maximize@trailing\nbogus=1\nwidget.nope=fill:#000000\nwidget.close.pressed=blob:x\n'
	skin := parse_skin('tested', '/x', text)
	assert skin.name == 'Tested'
	assert skin.bar_active.kind == .bitmap && skin.bar_active.slice[2] == 4
	assert skin.bar_inactive.kind == .fill && skin.bar_inactive.color == 0xcccccc
	close := skin.widgets['close'] or { panic('no close') }
	assert close.normal.kind == .vector && close.normal.color == 0xff0000
	assert close.hover.file == 'xh.vec' && !close.hover.has_color
	assert close.pressed.file == 'x.vec' // set by the all-states line; the bad override was ignored
	assert (skin.widgets['maximize'] or { panic('no max') }).size == 14
	assert skin.has_chrome && skin.chrome.kind == .tab && skin.chrome.tab_align == .right
	assert skin.chrome.widgets.len == 2 && skin.chrome.widgets[1].anchor == .trailing
	assert skin.problems.len == 3
}

fn test_widget_state_falls_back_to_normal() {
	w := SkinWidget{
		normal: Drawable{ kind: .fill, color: 1, has_color: true }
		hover: Drawable{ kind: .fill, color: 2, has_color: true }
	}
	assert w.state_drawable(false, false, false).color == 1
	assert w.state_drawable(true, false, false).color == 2
	assert w.state_drawable(true, true, false).color == 2 // no pressed art: hover's
	assert w.state_drawable(false, false, true).color == 1 // no inactive art: normal
}

fn test_widget_lists_round_trip_through_text_and_the_packed_word() {
	text := 'close@leading,minimize@leading,shade@trailing,maximize@trailing'
	widgets := widgets_from_text(text) or { panic('parse') }
	assert widgets_to_text(widgets) == text
	packed := widgets_pack(widgets)
	assert widgets_to_text(widgets_unpack(packed)) == text
	assert widgets_pack([]WidgetSpec{}) == 0
	assert widgets_from_text('close@middle') == none
	assert widgets_from_text('wobble@leading') == none
	assert widgets_unpack(0xf) == []WidgetSpec{} // action 6 does not exist
}

fn test_skin_ids_are_directory_safe() {
	assert skin_id_valid('my-skin_2')
	assert !skin_id_valid('')
	assert !skin_id_valid('../etc')
	assert !skin_id_valid('Skin')
	assert !skin_id_valid('a/b')
}
