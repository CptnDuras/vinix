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

// widgets_with sets one control's placement and returns the list in Settings'
// order: the leading run, then the trailing one, each in action order.
fn widgets_with(widgets []WidgetSpec, action WidgetAction, placement int) []WidgetSpec {
	mut out := []WidgetSpec{}
	for anchor in [WidgetAnchor.leading, WidgetAnchor.trailing] {
		for a in settings_widget_actions {
			p := if a == action { placement } else { widget_placement(widgets, a) }
			want := if anchor == .leading { 1 } else { 2 }
			if p == want {
				out << WidgetSpec{
					action: a
					anchor: anchor
				}
			}
		}
	}
	return out
}

fn (a &SettingsApp) current_chrome_widgets() []WidgetSpec {
	a.desktop.sync_skin()
	return a.desktop.chrome_spec().widgets
}

fn (a &SettingsApp) windows_pane_state() ChromeSpec {
	a.desktop.sync_skin()
	return a.desktop.chrome_spec()
}

fn (a &SettingsApp) windows_pane(width int) []ui2.Element {
	settings := a.desktop.settings
	spec := a.windows_pane_state()
	inner := width - 2 * settings_padding
	third := (inner - 2 * settings_row_gap) / 3
	catalog := skin_catalog()

	mut out := frame_elements(40 + catalog.len)
	mut y := settings_padding

	// Title bar: follow the look, a bar across the window, or a tab.
	out << settings_heading(tr('settings.windows.titlebar'), y, width)
	y += 22
	out << settings_note(tr('settings.windows.titlebar_note'), y, width)
	y += 22
	kind := settings.ov_title_kind
	out << settings_choice('${settings_action_title_kind}0', tr('settings.windows.follow'), settings_padding, y, third, kind == none)
	out << settings_choice('${settings_action_title_kind}1', tr('settings.windows.bar'), settings_padding + third + settings_row_gap, y, third, (kind or { TitleKind.tab }) == .full)
	out << settings_choice('${settings_action_title_kind}2', tr('settings.windows.tab'), settings_padding + 2 * (third + settings_row_gap), y, third, (kind or { TitleKind.full }) == .tab)
	y += 28 + 16

	// Where a tab sits.
	out << settings_heading(tr('settings.windows.tab_position'), y, width)
	y += 22
	align := settings.ov_tab_align
	out << settings_choice('${settings_action_tab_align}0', tr('settings.windows.follow'), settings_padding, y, third, align == none)
	out << settings_choice('${settings_action_tab_align}1', tr('settings.windows.pos_left'), settings_padding + third + settings_row_gap, y, third, (align or { TitleAlign.right }) == .left)
	out << settings_choice('${settings_action_tab_align}2', tr('settings.windows.pos_center'), settings_padding + 2 * (third + settings_row_gap), y, third, (align or { TitleAlign.left }) == .center)
	y += 28 + 6
	out << settings_choice('${settings_action_tab_align}3', tr('settings.windows.pos_right'), settings_padding + 2 * (third + settings_row_gap), y, third, (align or { TitleAlign.left }) == .right)
	y += 28 + 16

	// The controls: each off, or at one end of the bar.
	out << settings_heading(tr('settings.windows.widgets'), y, width)
	y += 22
	out << settings_note(tr('settings.windows.widgets_note'), y, width)
	y += 22
	widgets := spec.widgets
	label_w := 96
	choice_w := (inner - label_w - 2 * settings_row_gap) / 3
	for action in settings_widget_actions {
		placement := widget_placement(widgets, action)
		out << ui2.label('', widget_action_title(action), ui2.rect(f64(settings_padding), f64(y), f64(label_w), 28), ui2.TextStyle{
			color: body_text
			size: 12
		})
		for state in 0 .. 3 {
			text := match state {
				0 { tr('settings.windows.off') }
				1 { tr('settings.windows.pos_left') }
				else { tr('settings.windows.pos_right') }
			}
			x := settings_padding + label_w + settings_row_gap + state * (choice_w + settings_row_gap)
			out << settings_choice('${settings_action_widget}${widget_action_name(action)}.${state}', text, x, y, choice_w, placement == state)
		}
		y += 28 + 6
	}
	y += 10

	// The skin.
	out << settings_heading(tr('settings.windows.skin'), y, width)
	y += 22
	out << settings_note(tr('settings.windows.skin_note'), y, width)
	y += 22
	half := (inner - settings_row_gap) / 2
	mut index := 0
	for choice in 0 .. catalog.len + 2 {
		label := if choice == 0 {
			tr('settings.windows.follow')
		} else if choice == 1 {
			tr('settings.windows.skin_none')
		} else {
			catalog[choice - 2].name
		}
		selected := if choice == 0 {
			settings.skin_id == ''
		} else if choice == 1 {
			settings.skin_id == 'none'
		} else {
			settings.skin_id == catalog[choice - 2].id
		}
		col := index % 2
		x := if col == 0 { settings_padding } else { settings_padding + half + settings_row_gap }
		out << settings_choice('${settings_action_skin}${choice}', label, x, y, half, selected)
		if col == 1 {
			y += 28 + 8
		}
		index++
	}
	if index % 2 == 1 {
		y += 28 + 8
	}
	y += 8
	out << settings_choice(settings_action_reset_chrome, tr('settings.windows.reset'), settings_padding, y, 180, false)
	return out
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
	if event_id == settings_action_reset_chrome {
		a.desktop.settings.ov_title_kind = none
		a.desktop.settings.ov_tab_align = none
		a.desktop.settings.ov_widgets = none
		a.desktop.settings.skin_id = ''
		return true
	}
	return false
}
