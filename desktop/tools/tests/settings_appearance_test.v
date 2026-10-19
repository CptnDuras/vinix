// SPDX-License-Identifier: GPL-2.0-or-later
@[has_globals]
module main

import ui2

// Settings > Appearance: the title bar designer, the title-bar click actions and
// what choosing a look does to them.

fn appearance_fixture(preset string) (&Desktop, &SettingsApp) {
	mut desktop := &Desktop{
		canvas: Canvas{
			width: 1280
			height: 800
		}
	}
	desktop.settings.preset_id = preset
	mut app := &SettingsApp{
		desktop: desktop
		category: .appearance
	}
	return desktop, app
}

fn tree_ids(root ui2.Element, mut out []string) {
	if root.id.len > 0 {
		out << root.id
	}
	for child in root.children {
		tree_ids(child, mut out)
	}
}

fn run_of(widgets []WidgetSpec, anchor WidgetAnchor) []string {
	return widgets_run(widgets, anchor).map(widget_action_name(it.action))
}

fn press(mut app SettingsApp, x int, y int) {
	// The pointer reaches the application in the window body's coordinates.
	off := settings_sidebar_width + 1
	app.pointer_event(.down, .left, 0, x + off, y, 620, 376)
}

fn move_to(mut app SettingsApp, x int, y int) {
	off := settings_sidebar_width + 1
	app.pointer_event(.move, .left, 0, x + off, y, 620, 376)
}

fn release(mut app SettingsApp, x int, y int) {
	off := settings_sidebar_width + 1
	app.pointer_event(.up, .left, 0, x + off, y, 620, 376)
}

fn test_the_page_has_the_designer_its_sections_and_a_reset() {
	_, mut app := appearance_fixture('beos')
	root := app.build(ui2.rect(0, 0, 620, 410)) or { panic(err) }
	mut ids := []string{}
	tree_ids(root, mut ids)
	for tab in 0 .. appearance_tab_count {
		assert '${settings_action_atab}${tab}' in ids
	}
	assert settings_action_reset_chrome in ids
	// The look section lists every look.
	assert '${settings_action_theme}0' in ids
}

fn test_a_middle_click_rolls_up_and_a_double_click_zooms_unless_told_otherwise() {
	mut desktop, mut app := appearance_fixture('default')
	assert desktop.behavior().title_middle_click == .shade
	assert desktop.behavior().title_double_click == .maximize
	assert desktop.behavior().shade_enabled
	app.handle('${settings_action_title_mid}3') or { panic(err) } // minimise
	app.handle('${settings_action_title_dbl}2') or { panic(err) } // roll up
	assert desktop.behavior().title_middle_click == .hide
	assert desktop.behavior().title_double_click == .shade
	assert desktop.settings.ov_title_middle_click or { TitleAction.none_ } == .hide
	// Following the look removes the choice.
	app.handle('${settings_action_title_mid}0') or { panic(err) }
	app.handle('${settings_action_title_dbl}0') or { panic(err) }
	assert desktop.settings.ov_title_middle_click == none
	assert desktop.behavior().title_middle_click == .shade
	assert desktop.behavior().title_double_click == .maximize
	// A choice out of range changes nothing.
	app.handle('${settings_action_title_mid}9') or { panic(err) }
	assert desktop.settings.ov_title_middle_click == none
}

fn test_choosing_a_look_sets_the_window_arrangement_afresh() {
	mut desktop, mut app := appearance_fixture('default')
	desktop.settings.ov_title_kind = TitleKind.tab
	desktop.settings.ov_tab_align = TitleAlign.right
	desktop.settings.ov_tab_width = 40
	desktop.settings.ov_widgets = int(widgets_pack([WidgetSpec{ action: .close, anchor: .leading }]))
	desktop.settings.skin_id = 'none'
	desktop.settings.button_side = .left
	desktop.settings.ov_title_middle_click = TitleAction.hide
	app.handle('${settings_action_theme}${registry_index_of('beos')}') or { panic(err) }
	assert desktop.settings.preset_id == 'beos'
	assert desktop.settings.ov_title_kind == none
	assert desktop.settings.ov_tab_align == none
	assert desktop.settings.ov_tab_width == none
	assert desktop.settings.ov_widgets == none
	assert desktop.settings.skin_id == ''
	assert desktop.settings.button_side == .right
	// What a click does is the user's own, and survives.
	assert desktop.settings.ov_title_middle_click or { TitleAction.none_ } == .hide
	// Catalina still starts with its controls at the left.
	app.handle('${settings_action_theme}${registry_index_of('macos')}') or { panic(err) }
	assert desktop.settings.button_side == .left
}

fn test_the_window_buttons_setting_mirrors_a_look_that_has_its_own_controls() {
	mut desktop, _ := appearance_fixture('beos')
	right := desktop.chrome_spec().widgets
	assert run_of(right, .leading) == ['close']
	assert run_of(right, .trailing) == ['maximize']
	desktop.settings.button_side = .left
	left := desktop.chrome_spec().widgets
	assert run_of(left, .leading) == ['maximize']
	assert run_of(left, .trailing) == ['close']
	// The user's own arrangement is never mirrored behind their back.
	desktop.settings.ov_widgets = int(widgets_pack(right))
	assert run_of(desktop.chrome_spec().widgets, .leading) == ['close']
}

fn test_a_tab_width_choice_sets_the_share_or_fits() {
	mut desktop, mut app := appearance_fixture('beos')
	app.handle('${settings_action_tabwidth}3') or { panic(err) } // 50
	assert desktop.settings.ov_tab_width or { -1 } == 50
	spec := desktop.chrome_spec()
	assert spec.tab_sizing == .fraction && spec.tab_pct == 50
	app.handle('${settings_action_tabwidth}1') or { panic(err) } // fit
	assert desktop.settings.ov_tab_width or { -1 } == 0
	assert desktop.chrome_spec().tab_sizing == .fit
	app.handle('${settings_action_tabwidth}0') or { panic(err) } // follow
	assert desktop.settings.ov_tab_width == none
}

fn test_dragging_a_control_to_the_other_end_moves_it() {
	mut desktop, mut app := appearance_fixture('beos')
	pane_width := 620 - (settings_sidebar_width + 1)
	l := app.designer_layout_in(pane_width)
	close := l.placed.filter(it.action == .close)[0]
	press(mut app, close.rect.x + 3, close.rect.y + 3)
	assert app.dz_drag.active() && app.dz_drag.kind == .widget
	// Over the right end of the bar.
	move_to(mut app, l.bar.x + l.bar.w - 4, l.bar.y + 10)
	release(mut app, l.bar.x + l.bar.w - 4, l.bar.y + 10)
	assert !app.dz_drag.active()
	widgets := desktop.chrome_spec().widgets
	assert run_of(widgets, .leading) == []
	assert run_of(widgets, .trailing).len == 2
	assert run_of(widgets, .trailing)[0] == 'close'
}

fn test_dragging_a_control_onto_the_tray_takes_it_off_but_never_the_last() {
	mut desktop, mut app := appearance_fixture('beos')
	pane_width := 620 - (settings_sidebar_width + 1)
	l := app.designer_layout_in(pane_width)
	zoom := l.placed.filter(it.action == .maximize)[0]
	press(mut app, zoom.rect.x + 3, zoom.rect.y + 3)
	move_to(mut app, l.tray.x + 40, l.tray.y + 10)
	release(mut app, l.tray.x + 40, l.tray.y + 10)
	assert run_of(desktop.chrome_spec().widgets, .trailing) == []
	assert desktop.chrome_spec().widgets.len == 1
	// The one that is left stays.
	l2 := app.designer_layout_in(pane_width)
	close := l2.placed[0]
	press(mut app, close.rect.x + 3, close.rect.y + 3)
	move_to(mut app, l2.tray.x + 40, l2.tray.y + 10)
	release(mut app, l2.tray.x + 40, l2.tray.y + 10)
	assert desktop.chrome_spec().widgets.len == 1
}

fn test_a_press_that_goes_nowhere_is_a_click_and_a_chip_tap_toggles_a_control() {
	mut desktop, mut app := appearance_fixture('beos')
	pane_width := 620 - (settings_sidebar_width + 1)
	l := app.designer_layout_in(pane_width)
	// Tapping a control of the bar does nothing.
	close := l.placed[0]
	press(mut app, close.rect.x + 3, close.rect.y + 3)
	release(mut app, close.rect.x + 3, close.rect.y + 3)
	assert desktop.settings.ov_widgets == none
	// Tapping the chip of a control that is off the bar puts it on, at the
	// trailing end and outermost; tapping it again takes it off.
	shade := l.chips.filter(it.action == .shade)[0]
	press(mut app, shade.rect.x + 4, shade.rect.y + 4)
	release(mut app, shade.rect.x + 4, shade.rect.y + 4)
	assert run_of(desktop.chrome_spec().widgets, .trailing)[0] == 'shade'
	press(mut app, shade.rect.x + 4, shade.rect.y + 4)
	release(mut app, shade.rect.x + 4, shade.rect.y + 4)
	assert !desktop.chrome_spec().widgets.any(it.action == .shade)
}

fn test_dragging_the_grip_resizes_the_tab_and_dragging_the_tab_moves_it() {
	mut desktop, mut app := appearance_fixture('beos')
	pane_width := 620 - (settings_sidebar_width + 1)
	l := app.designer_layout_in(pane_width)
	assert l.is_tab
	press(mut app, l.handle.x + 2, l.handle.y + 5)
	assert app.dz_drag.kind == .handle
	move_to(mut app, l.frame.x + l.frame.w / 2, l.handle.y + 5)
	release(mut app, l.frame.x + l.frame.w / 2, l.handle.y + 5)
	assert desktop.settings.ov_tab_width or { -1 } == 50
	// Now the tab itself, towards the right-hand end.
	l2 := app.designer_layout_in(pane_width)
	press(mut app, l2.bar.x + 40, l2.bar.y + 12)
	assert app.dz_drag.kind == .tab
	move_to(mut app, l2.frame.x + l2.frame.w - 20, l2.bar.y + 12)
	release(mut app, l2.frame.x + l2.frame.w - 20, l2.bar.y + 12)
	assert desktop.settings.ov_tab_align or { TitleAlign.left } == .right
}

fn test_pointer_events_off_the_appearance_page_do_nothing() {
	mut desktop, mut app := appearance_fixture('beos')
	app.category = .taskbar
	press(mut app, 30, 30)
	assert !app.dz_drag.active()
	assert desktop.settings.ov_widgets == none
	// A stray release or move with no press is ignored.
	app.category = .appearance
	move_to(mut app, 30, 30)
	release(mut app, 30, 30)
	assert desktop.settings.ov_widgets == none && desktop.settings.ov_tab_width == none
}

fn test_a_search_for_windows_lands_on_the_title_bar_section() {
	_, mut app := appearance_fixture('default')
	app.choose_category(.windows)
	assert app.category == .appearance
	assert app.appearance_tab == appearance_tab_title
}

fn test_the_new_choices_cross_the_application_protocol_and_the_preferences_file() {
	state := AppWireState{
		settings: Settings{
			ov_title_middle_click: TitleAction.hide
			ov_tab_width:          40
			ov_widgets:            int(widgets_pack([
				WidgetSpec{ action: .menu, anchor: .leading },
				WidgetSpec{ action: .close, anchor: .leading },
			]))
		}
	}
	mut out := []u8{}
	wire_put_state(mut out, state)
	assert out.len == app_request_header_size - 20
	mut reader := WireReader{
		data: out
	}
	decoded := wire_take_state(mut reader) or { panic(err) }
	assert decoded.settings == state.settings
	// A tab width that is neither fit nor a share of the window is damage.
	bad := AppWireState{
		settings: Settings{
			ov_tab_width: 7
		}
	}
	mut bad_out := []u8{}
	wire_put_state(mut bad_out, bad)
	mut bad_reader := WireReader{
		data: bad_out
	}
	if _ := wire_take_state(mut bad_reader) {
		assert false, 'a tab width of 7 percent was accepted'
	}

	// The preferences file keeps them, in the user's order.
	text := desktop_encode_overrides(state.settings)
	assert text.contains('ov_title_middle_click=hide')
	assert text.contains('ov_tab_width=40')
	assert text.contains('ov_widgets=menu@leading,close@leading')
	mut round := Settings{}
	for line in text.split('\n') {
		eq := line.index('=') or { continue }
		desktop_parse_override(mut round, line[..eq], line[eq + 1..]) or { panic('unreadable: ${line}') }
	}
	assert round.ov_title_middle_click or { TitleAction.none_ } == .hide
	assert round.ov_tab_width or { -1 } == 40
	assert round.ov_widgets == state.settings.ov_widgets
	// A width the picker never offers is refused.
	mut refused := Settings{}
	assert desktop_parse_override(mut refused, 'ov_tab_width', '7') == none
	assert desktop_parse_override(mut refused, 'ov_tab_width', '0') != none
}
