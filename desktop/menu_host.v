// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Menu system — popup rendering + the window-menu host (spec F2/F3).
//
// Renders a Menu (menu.v) into a floating ui2 element tree the software
// renderer paints as a popup, and hosts the system window menu opened from a
// title-bar right-click. Per-application menus over VAPP remain deferred.
module main

import ui2

const menu_row_height = 24
const menu_separator_height = 7
const menu_width = 180
const menu_pad = 4

// window_menu_open reports whether the system window menu is showing.
fn (d &Desktop) window_menu_open() bool {
	return d.window_menu_id != 0
}

// open_window_menu shows the system window menu for a window at (x, y).
fn (mut d Desktop) open_window_menu(id int, x int, y int) {
	d.window_menu_id = id
	d.window_menu_x = x
	d.window_menu_y = y
	d.dirty = true
}

fn (mut d Desktop) close_window_menu() {
	if d.window_menu_id != 0 {
		d.window_menu_id = 0
		d.dirty = true
	}
}

// route_window_menu_action runs a system-window-menu action on the menu's
// target window (Blue spec F3) and dismisses the menu.
fn (mut d Desktop) route_window_menu_action(action string) {
	id := d.window_menu_id
	d.close_window_menu()
	match action {
		menu_action_close { d.close_window(id) }
		menu_action_shade { d.toggle_shade(id) }
		menu_action_minimize { d.minimize(id) }
		menu_action_zoom { d.toggle_maximize(id) }
		else { d.raise(id) } // 'about' (no-op for now) and any others
	}
}

// window_menu_element builds the popup for the open window menu. Item ids are
// the menu action ids (menu_action_*), so hit routing reuses the normal path.
fn (d &Desktop) window_menu_element() ui2.Element {
	theme := d.theme()
	index := d.window_index(d.window_menu_id) or { return ui2.view('menu.window', ui2.rect(0, 0, 0, 0), ui2.BoxStyle{ transparent: true }, []) }
	title := d.windows[index].title
	menu := system_window_menu(title, d.behavior().shade_enabled)

	mut children := frame_elements(menu.items.len)
	mut y := menu_pad
	for item in menu.items {
		if item.separator {
			children << ui2.view('', ui2.rect(f64(menu_pad), f64(y + menu_separator_height / 2),
				f64(menu_width - 2 * menu_pad), 1), ui2.BoxStyle{
				bg: theme.title_divider
			}, [])
			y += menu_separator_height
			continue
		}
		hovered := d.hover == item.action
		text_color := if !item.enabled {
			theme.title_text_inactive
		} else {
			body_text
		}
		bg := if hovered && item.enabled { theme.accent_dim } else { u32(0) }
		// A disabled item carries no action id, so it cannot be clicked.
		action_id := if item.enabled { item.action } else { '' }
		children << ui2.button(action_id, item.label, ui2.rect(f64(menu_pad), f64(y),
			f64(menu_width - 2 * menu_pad), f64(menu_row_height)), ui2.BoxStyle{
			bg: bg
			transparent: bg == 0
			radius: 3
		}, ui2.TextStyle{
			color: text_color
			size: 13
			align: .left
		})
		y += menu_row_height
	}

	total_h := y + menu_pad
	// Keep the popup on-screen.
	mut px := d.window_menu_x
	mut py := d.window_menu_y
	if px + menu_width > d.canvas.width {
		px = d.canvas.width - menu_width
	}
	if py + total_h > d.canvas.height {
		py = d.canvas.height - total_h
	}
	return ui2.view('menu.window', ui2.rect(f64(px), f64(py), f64(menu_width), f64(total_h)),
		ui2.BoxStyle{
		bg: theme.window_body
		radius: 6
	}, children)
}
