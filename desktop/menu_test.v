// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for the menu model (F1) and system window menu (F3). Pure data, no ui2.
module main

// (a) a menu can hold nested submenus, separators, disabled and checked items.
fn test_menu_can_nest() {
	m := Menu{
		title: 'File'
		items: [
			MenuItem{ label: 'New', action: 'new' },
			MenuItem{ separator: true },
			MenuItem{ label: 'Recent', submenu: [
				MenuItem{ label: 'a.txt', action: 'open.a' },
				MenuItem{ label: 'b.txt', action: 'open.b' },
			] },
			MenuItem{ label: 'Word Wrap', action: 'wrap', checked: true },
			MenuItem{ label: 'Save', action: 'save', enabled: false },
		]
	}
	// 5 top rows + 2 submenu rows = 7 visible rows.
	assert menu_visible_item_count(m.items) == 7
	assert menu_has_action(m.items, 'open.b') // found in a submenu
	assert !menu_has_action(m.items, 'nope')
}

// (b) the checked/disabled flags round-trip.
fn test_item_flags() {
	it := MenuItem{ label: 'X', action: 'x', checked: true, enabled: false }
	assert it.checked
	assert !it.enabled
	// default enabled is true.
	assert MenuItem{ label: 'Y', action: 'y' }.enabled
}

// ── F3 system window menu ──────────────────────────────────────────

fn test_system_menu_has_five_actions() {
	m := system_window_menu('Files', true)
	for a in [menu_action_about, menu_action_shade, menu_action_minimize,
		menu_action_zoom, menu_action_close] {
		assert menu_has_action(m.items, a)
	}
}

// (c) Shade row disabled when shade_enabled is false.
fn test_system_menu_shade_reflects_state() {
	on := system_window_menu('W', true)
	off := system_window_menu('W', false)
	mut on_shade_enabled := false
	mut off_shade_enabled := true
	for it in on.items {
		if it.action == menu_action_shade {
			on_shade_enabled = it.enabled
		}
	}
	for it in off.items {
		if it.action == menu_action_shade {
			off_shade_enabled = it.enabled
		}
	}
	assert on_shade_enabled
	assert !off_shade_enabled
}

// The window menu title carries the window name (for About + the bar label).
fn test_system_menu_titled() {
	m := system_window_menu('Calculator', true)
	assert m.title == 'Calculator'
	assert menu_has_action(m.items, menu_action_about)
}
