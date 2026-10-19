module main

fn bar_spec() ChromeSpec {
	return ChromeSpec{
		widgets: [
			WidgetSpec{ action: .close, anchor: .leading },
			WidgetSpec{ action: .minimize, anchor: .trailing },
			WidgetSpec{ action: .maximize, anchor: .trailing },
		]
	}
}

fn tab_spec(align TitleAlign, pct int) ChromeSpec {
	sizing, p := tab_sizing_for(pct)
	return ChromeSpec{
		kind: .tab
		tab_align: align
		tab_sizing: sizing
		tab_pct: p
		widgets: [
			WidgetSpec{ action: .close, anchor: .leading },
			WidgetSpec{ action: .maximize, anchor: .trailing },
		]
	}
}

fn placed_for(l DzLayout, action WidgetAction) DzPlaced {
	for p in l.placed {
		if p.action == action {
			return p
		}
	}
	panic('not placed')
}

fn test_a_full_bar_spans_the_frame_and_controls_sit_at_their_ends() {
	l := designer_layout(bar_spec(), 10, 20, 400, DzMetrics{})
	assert l.bar == DzRect{10, 20, 400, 24}
	assert !l.is_tab
	close := placed_for(l, .close)
	assert close.rect.x == 10 + 6
	zoom := placed_for(l, .maximize)
	mini := placed_for(l, .minimize)
	// Trailing controls run in from the right, outermost first: zoom is the
	// last in the list, so it is the innermost of the two.
	assert mini.rect.x + mini.rect.w == 10 + 400 - 6
	assert zoom.rect.x + zoom.rect.w < mini.rect.x
	// Everything is centred on the bar's height.
	assert close.rect.y == 20 + (24 - 16) / 2
}

fn test_a_tab_is_only_as_wide_as_its_share_and_sits_where_it_is_aligned() {
	left := designer_layout(tab_spec(.left, 40), 0, 0, 400, DzMetrics{})
	assert left.bar == DzRect{0, 0, 160, 24}
	assert left.is_tab
	centre := designer_layout(tab_spec(.center, 50), 0, 0, 400, DzMetrics{})
	assert centre.bar == DzRect{100, 0, 200, 24}
	right := designer_layout(tab_spec(.right, 25), 0, 0, 400, DzMetrics{})
	assert right.bar.x + right.bar.w == 400
	// A tab's controls are inside the tab, not at the window's edges.
	assert placed_for(right, .maximize).rect.x >= right.bar.x
	assert placed_for(right, .maximize).rect.x + 16 <= 400
}

fn test_a_fit_tab_wraps_title_and_controls() {
	l := designer_layout(tab_spec(.left, 0), 0, 0, 400, DzMetrics{})
	// two controls, one gap's worth between none (one per end), a title, two insets
	assert l.bar.w == 16 + 16 + 48 + 2 * 6 + 2 * 10
	assert l.bar.w < 400
}

fn test_the_grip_is_on_the_edge_facing_the_window_middle() {
	left := designer_layout(tab_spec(.left, 40), 0, 0, 400, DzMetrics{})
	assert left.handle.x == left.bar.x + left.bar.w - 3
	right := designer_layout(tab_spec(.right, 40), 0, 0, 400, DzMetrics{})
	assert right.handle.x == right.bar.x - 5
	assert designer_layout(bar_spec(), 0, 0, 400, DzMetrics{}).handle == DzRect{}
}

fn test_hits_prefer_controls_then_the_grip_then_the_bar() {
	l := designer_layout(tab_spec(.left, 40), 0, 0, 400, DzMetrics{})
	zoom := placed_for(l, .maximize)
	h := designer_hit(l, zoom.rect.x + 2, zoom.rect.y + 2)
	assert h.kind == .widget && h.action == .maximize
	assert designer_hit(l, l.handle.x + 1, 2).kind == .handle
	assert designer_hit(l, l.bar.x + 30, 2).kind == .tab
	assert designer_hit(l, 399, 2).kind == .nothing
	chip := l.chips[2]
	hc := designer_hit(l, chip.rect.x + 2, chip.rect.y + 2)
	assert hc.kind == .chip && hc.action == .maximize
	full := designer_layout(bar_spec(), 0, 0, 400, DzMetrics{})
	assert designer_hit(full, 200, 12).kind == .bar
}

fn test_chips_say_which_controls_are_on_the_bar() {
	l := designer_layout(bar_spec(), 0, 0, 400, DzMetrics{})
	assert l.chips.len == 5
	assert l.chips.filter(it.on_bar).map(widget_action_name(it.action)) == ['close', 'minimize', 'maximize']
	assert !l.chips[3].on_bar && !l.chips[4].on_bar
}

fn test_dropping_on_the_bar_picks_the_end_and_the_slot() {
	l := designer_layout(bar_spec(), 0, 0, 400, DzMetrics{})
	// Left half, left of close: first of the leading run.
	d := designer_drop(l, .shade, 2, 12)
	assert d.kind == .place && d.anchor == .leading && d.position == 0
	// Left half, right of close: after it.
	after := designer_drop(l, .shade, 60, 12)
	assert after.anchor == .leading && after.position == 1
	// Right half, at the far right: outermost of the trailing run.
	far := designer_drop(l, .shade, 398, 12)
	assert far.anchor == .trailing && far.position == 0
	// Right half, towards the middle: after both trailing controls.
	inner := designer_drop(l, .shade, 250, 12)
	assert inner.anchor == .trailing && inner.position == 2
	// The dragged control does not count against its own slot.
	own := designer_drop(l, .close, 60, 12)
	assert own.anchor == .leading && own.position == 0
}

fn test_dropping_on_the_tray_removes_and_elsewhere_cancels() {
	l := designer_layout(bar_spec(), 0, 0, 400, DzMetrics{})
	assert designer_drop(l, .close, 200, l.tray.y + 5).kind == .remove
	assert designer_drop(l, .close, 200, l.body.y + 20).kind == .cancel
	assert designer_drop(l, .close, 900, 900).kind == .cancel
}

fn test_applying_a_drop_changes_the_list() {
	l := designer_layout(bar_spec(), 0, 0, 400, DzMetrics{})
	moved := designer_apply(l.spec.widgets, .minimize, designer_drop(l, .minimize, 2, 12))
	assert widgets_run(moved, .leading).map(widget_action_name(it.action)) == ['minimize', 'close']
	removed := designer_apply(l.spec.widgets, .close, designer_drop(l, .close, 200, l.tray.y + 5))
	assert removed.len == 2
	same := designer_apply(l.spec.widgets, .close, designer_drop(l, .close, 900, 900))
	assert same == l.spec.widgets
	// The last control stays.
	one := [WidgetSpec{ action: .close, anchor: .leading }]
	assert designer_apply(one, .close, DzDrop{ kind: .remove }) == one
}

fn test_dragging_the_grip_sets_the_tab_width_in_steps() {
	l := designer_layout(tab_spec(.left, 40), 0, 0, 400, DzMetrics{})
	assert designer_tab_percent(l, 200) == 50
	assert designer_tab_percent(l, 203) == 50
	assert designer_tab_percent(l, 400) == 100
	assert designer_tab_percent(l, 9999) == 100
	assert designer_tab_percent(l, 5) == 10
	r := designer_layout(tab_spec(.right, 40), 0, 0, 400, DzMetrics{})
	assert designer_tab_percent(r, 200) == 50
	c := designer_layout(tab_spec(.center, 40), 0, 0, 400, DzMetrics{})
	// A centred tab grows both ways: half its width is the distance from the middle.
	assert designer_tab_percent(c, 300) == 50
}

fn test_dragging_a_tab_snaps_to_the_nearest_alignment() {
	l := designer_layout(tab_spec(.left, 25), 0, 0, 400, DzMetrics{})
	assert designer_tab_align(l, 20) == .left
	assert designer_tab_align(l, 210) == .center
	assert designer_tab_align(l, 390) == .right
}

fn test_the_marker_shows_where_a_drop_would_land() {
	l := designer_layout(bar_spec(), 0, 0, 400, DzMetrics{})
	first := designer_drop(l, .shade, 2, 12)
	assert designer_insertion_x(l, .shade, first) == placed_for(l, .close).rect.x - 2
	last := designer_drop(l, .shade, 250, 12)
	x := designer_insertion_x(l, .shade, last)
	assert x < placed_for(l, .maximize).rect.x
	assert designer_insertion_x(l, .shade, DzDrop{}) == -1
}
