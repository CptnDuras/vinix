// SPDX-License-Identifier: GPL-2.0-or-later
@[has_globals]
module main

import ui2

fn chrome_find(el &ui2.Element, id string) ?&ui2.Element {
	if el.id == id {
		return el
	}
	for i in 0 .. el.children.len {
		if found := chrome_find(&el.children[i], id) {
			return found
		}
	}
	return none
}

fn chrome_window(preset string) (Desktop, int) {
	mut desktop := Desktop{
		canvas: Canvas{
			width: 900
			height: 700
		}
	}
	desktop.settings.preset_id = preset
	id := desktop.spawn('Welcome', .welcome, 100, 80, 420, 280)
	return desktop, id
}

fn test_the_default_look_keeps_one_full_width_bar_with_three_buttons() {
	mut desktop, id := chrome_window('default')
	index := desktop.window_index(id) or { panic('no window') }
	frame := desktop.window_element(index)
	bar := chrome_find(&frame, desktop.windows[index].id_titlebar) or { panic('no bar') }
	assert int(bar.frame.x) == 0
	assert int(bar.frame.width) == 420
	assert chrome_find(&frame, desktop.windows[index].id_close) != none
	assert chrome_find(&frame, desktop.windows[index].id_minimize) != none
	assert chrome_find(&frame, desktop.windows[index].id_maximize) != none
	assert chrome_find(&frame, desktop.windows[index].id_shade) == none
}

fn test_beos_title_is_a_tab_narrower_than_its_window() {
	mut desktop, id := chrome_window('beos')
	index := desktop.window_index(id) or { panic('no window') }
	frame := desktop.window_element(index)
	bar := chrome_find(&frame, desktop.windows[index].id_titlebar) or { panic('no bar') }
	assert int(bar.frame.width) < 420
	assert int(bar.frame.x) == 0
	close := chrome_find(&frame, desktop.windows[index].id_close) or { panic('no close') }
	zoom := chrome_find(&frame, desktop.windows[index].id_maximize) or { panic('no zoom') }
	// Close at the tab's left, zoom at its right, both inside it.
	assert int(close.frame.x) < int(zoom.frame.x)
	assert int(zoom.frame.x) + int(zoom.frame.width) <= int(bar.frame.width)
	assert chrome_find(&frame, desktop.windows[index].id_minimize) == none
}

fn test_the_body_of_a_tabbed_window_starts_below_the_tab() {
	mut desktop, id := chrome_window('beos')
	index := desktop.window_index(id) or { panic('no window') }
	frame := desktop.window_element(index)
	body := chrome_find(&frame, desktop.windows[index].id_body) or { panic('no body') }
	assert int(body.frame.y) == desktop.theme().title_height
	assert int(body.frame.width) == 420
}

fn test_platinum_has_a_close_box_and_zoom_and_collapse_boxes() {
	mut desktop, id := chrome_window('platinum')
	desktop.settings.preset_id = 'platinum'
	index := desktop.window_index(id) or { panic('no window') }
	frame := desktop.window_element(index)
	w := desktop.windows[index]
	close := chrome_find(&frame, w.id_close) or { panic('no close') }
	zoom := chrome_find(&frame, w.id_maximize) or { panic('no zoom') }
	assert int(close.frame.x) < 20
	assert int(zoom.frame.x) > 300
	// The collapse box needs shading to be on for the look; if it is, it sits
	// beside the zoom box.
	if desktop.behavior().shade_enabled {
		shade := chrome_find(&frame, w.id_shade) or { panic('no shade') }
		assert int(shade.frame.x) < int(zoom.frame.x)
	}
}

fn test_pressing_the_shade_widget_rolls_the_window_up() {
	mut desktop, id := chrome_window('beos')
	assert desktop.behavior().shade_enabled
	desktop.toggle_shade(id)
	index := desktop.window_index(id) or { panic('no window') }
	assert desktop.windows[index].shaded
}

fn settings_for_chrome() &SettingsApp {
	mut desktop := &Desktop{
		canvas: Canvas{
			width: 900
			height: 700
		}
	}
	return &SettingsApp{
		desktop: desktop
		category: .windows
	}
}

fn test_settings_windows_pane_sets_title_kind_and_tab_position() {
	mut app := settings_for_chrome()
	assert app.handle_windows('${settings_action_title_kind}2')
	assert app.desktop.settings.ov_title_kind or { TitleKind.full } == .tab
	assert app.handle_windows('${settings_action_tab_align}2')
	assert app.desktop.settings.ov_tab_align or { TitleAlign.left } == .center
	assert app.handle_windows('${settings_action_title_kind}0')
	assert app.desktop.settings.ov_title_kind == none
}

fn test_settings_windows_pane_places_each_control_independently() {
	mut app := settings_for_chrome()
	// From the stock three on the right: add Menu at the left, drop Minimise.
	assert app.handle_windows('${settings_action_widget}menu.1')
	assert app.handle_windows('${settings_action_widget}minimize.0')
	list := widgets_unpack(u32(app.desktop.settings.ov_widgets or { -1 }))
	assert widget_placement(list, .menu) == 1
	assert widget_placement(list, .minimize) == 0
	assert widget_placement(list, .close) == 2
	assert widget_placement(list, .maximize) == 2
	// The compositor then lays those out as chosen.
	spec := app.desktop.chrome_spec()
	assert spec.widgets.len == list.len
}

fn test_settings_skin_choices_and_reset() {
	mut app := settings_for_chrome()
	assert app.handle_windows('${settings_action_skin}1')
	assert app.desktop.settings.skin_id == 'none'
	assert app.handle_windows('${settings_action_skin}2')
	assert app.desktop.settings.skin_id == skin_catalog()[0].id
	assert app.handle_windows('${settings_action_skin}0')
	assert app.desktop.settings.skin_id == ''
	app.desktop.settings.ov_title_kind = TitleKind.tab
	app.desktop.settings.ov_widgets = 1
	assert app.handle_windows(settings_action_reset_chrome)
	assert app.desktop.settings.ov_title_kind == none
	assert app.desktop.settings.ov_widgets == none
}

fn test_the_windows_pane_builds_every_control() {
	mut app := settings_for_chrome()
	elements := app.windows_pane(560)
	mut ids := []string{}
	for e in elements {
		ids << e.id
	}
	assert '${settings_action_title_kind}1' in ids
	assert '${settings_action_tab_align}3' in ids
	assert '${settings_action_widget}shade.2' in ids
	assert '${settings_action_skin}1' in ids
	assert settings_action_reset_chrome in ids
}

fn test_widgets_with_keeps_leading_before_trailing_in_action_order() {
	start := stock_widgets(false, false)
	moved := widgets_with(start, .shade, 1)
	assert widgets_to_text(moved) == 'shade@leading,close@trailing,minimize@trailing,maximize@trailing'
}
