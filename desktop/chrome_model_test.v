module main

fn widget_ids(widgets []WidgetSpec, slots []WidgetSlot) []string {
	mut out := []string{}
	for slot in slots {
		out << widget_action_name(widgets[slot.index].action)
	}
	return out
}

fn slot_for(widgets []WidgetSpec, slots []WidgetSlot, action WidgetAction) WidgetSlot {
	for slot in slots {
		if widgets[slot.index].action == action {
			return slot
		}
	}
	panic('no slot')
}

// The stock layouts must put each button where it has always been.
fn test_stock_flat_buttons_on_the_right_put_close_outermost() {
	w := stock_widgets(false, false)
	slots := layout_widgets(w, 400, 30, 20, 4, 8)
	close := slot_for(w, slots, .close)
	zoom := slot_for(w, slots, .maximize)
	mini := slot_for(w, slots, .minimize)
	assert close.x == 400 - 8 - 20
	assert zoom.x == close.x - 24
	assert mini.x == zoom.x - 24
	assert close.y == 5
}

fn test_stock_flat_buttons_on_the_left_run_close_minimise_zoom() {
	w := stock_widgets(false, true)
	slots := layout_widgets(w, 400, 30, 20, 4, 8)
	assert slot_for(w, slots, .close).x == 8
	assert slot_for(w, slots, .minimize).x == 32
	assert slot_for(w, slots, .maximize).x == 56
}

fn test_traffic_lights_read_red_yellow_green_at_either_end() {
	for left in [true, false] {
		w := stock_widgets(true, left)
		slots := layout_widgets(w, 400, 30, 12, 8, 8)
		c := slot_for(w, slots, .close).x
		m := slot_for(w, slots, .minimize).x
		z := slot_for(w, slots, .maximize).x
		assert c < m && m < z
	}
	w := stock_widgets(true, false)
	slots := layout_widgets(w, 400, 30, 12, 8, 8)
	assert slot_for(w, slots, .maximize).x == 400 - 8 - 12
}

fn test_widgets_may_differ_in_size_and_each_is_centred() {
	w := [
		WidgetSpec{ action: .close, anchor: .leading, size: 10 },
		WidgetSpec{ action: .menu, anchor: .leading, size: 20 },
	]
	slots := layout_widgets(w, 200, 30, 16, 3, 5)
	assert slots[0].x == 5 && slots[0].y == 10
	assert slots[1].x == 5 + 10 + 3 && slots[1].y == 5
}

fn test_extent_counts_gaps_between_not_around() {
	w := stock_widgets(false, false)
	assert widget_extent(w, .trailing, 20, 4) == 3 * 20 + 2 * 4
	assert widget_extent(w, .leading, 20, 4) == 0
}

fn test_a_fit_tab_wraps_its_content_and_never_exceeds_the_window() {
	spec := ChromeSpec{ kind: .tab, tab_sizing: .fit, tab_pad: 8 }
	assert tab_width(spec, 500, 100) == 116
	assert tab_width(spec, 90, 100) == 90
}

fn test_fixed_and_fraction_tabs() {
	assert tab_width(ChromeSpec{ kind: .tab, tab_sizing: .fixed, tab_px: 150 }, 500, 10) == 150
	assert tab_width(ChromeSpec{ kind: .tab, tab_sizing: .fraction, tab_pct: 40 }, 500, 10) == 200
}

fn test_tab_alignment_places_the_tab_along_the_top() {
	assert tab_x(ChromeSpec{ tab_align: .left }, 500, 100) == 0
	assert tab_x(ChromeSpec{ tab_align: .center }, 500, 100) == 200
	assert tab_x(ChromeSpec{ tab_align: .right }, 500, 100) == 400
}

fn test_action_names_match_element_id_parts() {
	assert widget_action_name(.close) == 'close'
	assert widget_action_name(.shade) == 'shade'
	assert widget_action_name(.menu) == 'menu'
}

fn run_names(widgets []WidgetSpec, anchor WidgetAnchor) []string {
	return widgets_run(widgets, anchor).map(widget_action_name(it.action))
}

fn test_mirroring_swaps_each_widgets_end_and_keeps_run_order() {
	beos := [
		WidgetSpec{ action: .close, anchor: .leading },
		WidgetSpec{ action: .maximize, anchor: .trailing },
		WidgetSpec{ action: .shade, anchor: .trailing },
	]
	mirrored := widgets_mirrored(beos)
	assert run_names(mirrored, .leading) == ['maximize', 'shade']
	assert run_names(mirrored, .trailing) == ['close']
	assert widgets_mirrored(mirrored) == beos
}

fn test_moving_a_widget_places_it_among_one_ends_widgets() {
	list := [
		WidgetSpec{ action: .close, anchor: .leading },
		WidgetSpec{ action: .minimize, anchor: .leading },
		WidgetSpec{ action: .maximize, anchor: .trailing },
	]
	// To the other end, outermost.
	a := widgets_moved(list, .close, .trailing, 0)
	assert run_names(a, .leading) == ['minimize']
	assert run_names(a, .trailing) == ['close', 'maximize']
	// Within its own end: minimise ahead of close.
	b := widgets_moved(list, .minimize, .leading, 0)
	assert run_names(b, .leading) == ['minimize', 'close']
	// A position past the run's end appends; a negative one is outermost.
	c := widgets_moved(list, .close, .trailing, 99)
	assert run_names(c, .trailing) == ['maximize', 'close']
	d := widgets_moved(list, .maximize, .leading, -3)
	assert run_names(d, .leading) == ['maximize', 'close', 'minimize']
	assert run_names(d, .trailing) == []
	// A widget that was absent is added.
	e := widgets_moved(list, .shade, .trailing, 1)
	assert run_names(e, .trailing) == ['maximize', 'shade']
	// Putting a widget where it already is changes nothing.
	assert widgets_moved(list, .close, .leading, 0) == list
	// Per-widget fields survive the move.
	sized := [WidgetSpec{ action: .close, anchor: .leading, size: 14, skin: 'x' }]
	moved := widgets_moved(sized, .close, .trailing, 0)
	assert moved[0].size == 14 && moved[0].skin == 'x' && moved[0].anchor == .trailing
}

fn test_removing_a_widget_leaves_the_rest_in_order() {
	list := [
		WidgetSpec{ action: .close, anchor: .leading },
		WidgetSpec{ action: .minimize, anchor: .trailing },
		WidgetSpec{ action: .maximize, anchor: .trailing },
	]
	assert run_names(widgets_removed(list, .minimize), .trailing) == ['maximize']
	assert widgets_removed(list, .menu) == list
}

fn test_a_percentage_picks_the_tab_sizing() {
	s0, p0 := tab_sizing_for(0)
	assert s0 == .fit && p0 == 0
	s1, p1 := tab_sizing_for(40)
	assert s1 == .fraction && p1 == 40
	_, p2 := tab_sizing_for(400)
	assert p2 == 100
	spec := ChromeSpec{ tab_sizing: s1, tab_pct: p1 }
	assert tab_width(spec, 500, 10) == 200
}

fn test_a_widget_list_survives_packing_in_the_users_order() {
	list := [
		WidgetSpec{ action: .minimize, anchor: .leading },
		WidgetSpec{ action: .close, anchor: .leading },
		WidgetSpec{ action: .maximize, anchor: .trailing },
	]
	assert widgets_unpack(widgets_pack(list)) == list
}
