// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Settings > Windows: the shape of a window's title bar, which controls it has
// and where, and the skin it wears (Blue spec B5). Each is an override of the
// look in force; "Follow the look" removes it.
module main

import ui2

// The controls Settings offers, in the order a run of them is laid out: close
// first, so it is outermost at whichever end it is placed.
const settings_widget_actions = [WidgetAction.close, .minimize, .maximize, .shade, .menu]

fn widget_action_title(action WidgetAction) string {
	return match action {
		.close { tr('settings.windows.action.close') }
		.minimize { tr('settings.windows.action.minimize') }
		.maximize { tr('settings.windows.action.maximize') }
		.shade { tr('settings.windows.action.shade') }
		.menu { tr('settings.windows.action.menu') }
	}
}

// widget_placement is 0 for absent, 1 for the leading end and 2 for the trailing
// end.
fn widget_placement(widgets []WidgetSpec, action WidgetAction) int {
	for w in widgets {
		if w.action == action {
			return if w.anchor == .leading { 1 } else { 2 }
		}
	}
	return 0
}

// widgets_with sets one control's placement from the controls table: absent,
// at the leading end or at the trailing end. The others keep their order, and a
// control newly placed goes innermost at its end. A bar keeps its last control.
fn widgets_with(widgets []WidgetSpec, action WidgetAction, placement int) []WidgetSpec {
	return match placement {
		0 { if widgets.len <= 1 { widgets } else { widgets_removed(widgets, action) } }
		1 { widgets_moved(widgets, action, .leading, widgets.len) }
		else { widgets_moved(widgets, action, .trailing, widgets.len) }
	}
}

fn (a &SettingsApp) current_chrome_widgets() []WidgetSpec {
	a.desktop.sync_skin()
	return a.desktop.chrome_spec().widgets
}

fn (a &SettingsApp) windows_pane_state() ChromeSpec {
	a.desktop.sync_skin()
	return a.desktop.chrome_spec()
}

fn (mut a SettingsApp) handle_windows(event_id string) bool {
	if event_id.starts_with(settings_action_title_kind) {
		match event_id[settings_action_title_kind.len..].int() {
			0 { a.desktop.settings.ov_title_kind = none }
			1 { a.desktop.settings.ov_title_kind = TitleKind.full }
			2 { a.desktop.settings.ov_title_kind = TitleKind.tab }
			else {}
		}
		return true
	}
	if event_id.starts_with(settings_action_tab_align) {
		match event_id[settings_action_tab_align.len..].int() {
			0 { a.desktop.settings.ov_tab_align = none }
			1 { a.desktop.settings.ov_tab_align = TitleAlign.left }
			2 { a.desktop.settings.ov_tab_align = TitleAlign.center }
			3 { a.desktop.settings.ov_tab_align = TitleAlign.right }
			else {}
		}
		return true
	}
	if event_id.starts_with(settings_action_widget) {
		rest := event_id[settings_action_widget.len..]
		dot := rest.index('.') or { return true }
		action := widget_action_from_name(rest[..dot]) or { return true }
		placement := rest[dot + 1..].int()
		if placement < 0 || placement > 2 {
			return true
		}
		current := if packed := a.desktop.settings.ov_widgets {
			widgets_unpack(u32(packed))
		} else {
			a.current_chrome_widgets()
		}
		a.desktop.settings.ov_widgets = int(widgets_pack(widgets_with(current, action, placement)))
		return true
	}
	if event_id.starts_with(settings_action_skin) {
		choice := event_id[settings_action_skin.len..].int()
		catalog := skin_catalog()
		if choice == 0 {
			a.desktop.settings.skin_id = ''
		} else if choice == 1 {
			a.desktop.settings.skin_id = 'none'
		} else if choice - 2 < catalog.len {
			a.desktop.settings.skin_id = catalog[choice - 2].id
		}
		return true
	}
	if event_id.starts_with(settings_action_startmenu) {
		choice := event_id[settings_action_startmenu.len..].int()
		if choice >= int(StartMenuStyle.follow_look) && choice <= int(StartMenuStyle.kmenu) {
			a.desktop.settings.start_menu = unsafe { StartMenuStyle(choice) }
		}
		return true
	}
	if event_id.starts_with(settings_action_atab) {
		tab := event_id[settings_action_atab.len..].int()
		if tab >= 0 && tab < appearance_tab_count {
			a.appearance_tab = tab
			if tab == appearance_tab_skin {
				// A theme dropped in a folder since the list was read shows now.
				skin_catalog_cache.loaded = false
			}
		}
		return true
	}
	if event_id.starts_with(settings_action_tabwidth) {
		choice := event_id[settings_action_tabwidth.len..].int()
		if choice >= 0 && choice < settings_tab_width_choices.len {
			percent := settings_tab_width_choices[choice]
			a.desktop.settings.ov_tab_width = if percent < 0 { none } else { ?int(percent) }
		}
		return true
	}
	for prefix in [settings_action_title_dbl, settings_action_title_mid] {
		if event_id.starts_with(prefix) {
			choice := event_id[prefix.len..].int()
			if choice < 0 || choice > settings_title_actions.len {
				return true
			}
			picked := if choice == 0 { none } else { ?TitleAction(settings_title_actions[choice - 1]) }
			if prefix == settings_action_title_dbl {
				a.desktop.settings.ov_title_double_click = picked
			} else {
				a.desktop.settings.ov_title_middle_click = picked
			}
			return true
		}
	}
	if event_id == settings_action_reset_chrome {
		a.reset_window_look()
		return true
	}
	return false
}

// reset_window_look puts everything the user changed about the windows' shape
// back to what the look does on its own: the title bar, its controls, the tab
// and the skin, and which end the buttons mirror to.
fn (mut a SettingsApp) reset_window_look() {
	a.desktop.settings.ov_title_kind = none
	a.desktop.settings.ov_tab_align = none
	a.desktop.settings.ov_tab_width = none
	a.desktop.settings.ov_widgets = none
	a.desktop.settings.skin_id = ''
	a.desktop.settings.button_side = .right
	a.desktop.settings.start_menu = .follow_look
}
