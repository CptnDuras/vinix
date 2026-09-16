// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Shell — the top bar panel (spec E1/E2/E6).
//
// A top-edge full-width panel hosting a leading system-menu item and a trailing
// clock, the arrangement classic Mac (Platinum) and GNOME use. It is rendered
// only when the resolved shell (EffectiveShell.has_top_bar) asks for it, so the
// default/Windows-style bottom-taskbar arrangement is unchanged.
module main

import ui2

const top_bar_height = 26
const top_bar_action_system = 'taskbar.system'
const top_bar_app_menu_id = 'topbar.app_menu'
const top_bar_launcher_id = 'topbar.launcher'
const top_bar_tray_id = 'topbar.tray'
const tray_icon_size = 18
const tray_gap = 4
const tray_pad = 10

// top_bar_element builds the top panel. Item ids are stable so hit routing and
// tests can find them:
//   'topbar'            the panel view
//   'taskbar.system'    the leading system-menu button
//   'topbar.app_menu'   the global app-menu slot (Blue spec F2, when the
//                       resolved menu_placement is .global and a window is
//                       focused) — renders the focused window's menu titles
//   'topbar.clock'      the trailing clock label
fn (d &Desktop) top_bar_element() ui2.Element {
	theme := d.theme()
	width := d.canvas.width

	mut children := frame_elements(7)

	// Leading: the system menu (the Blue leaf / Apple-style menu). Reuses the
	// start-toggle action so clicking it opens the system menu host.
	children << ui2.button_with_image(top_bar_action_system, '', 'builtin:vinix', ui2.rect(f64(taskbar_padding), 2, f64(start_button_width), f64(top_bar_height - 4)), ui2.BoxStyle{
		bg: if d.start_menu_open || d.hover == top_bar_action_system {
			theme.accent
		} else {
			theme.accent_dim
		}
		radius: 4
	}, ui2.TextStyle{
		color: theme.taskbar_text_active
	})

	// Global app-menu slot (Blue spec F2): when the resolved menu_placement is
	// .global, the focused window's menu is hosted here in the top bar (the
	// Platinum / GNOME arrangement). The Shell owns only the slot; the menu
	// content is F's system_window_menu of the focused window. The slot targets
	// this position — F fills it — which keeps the E↔F graph acyclic.
	if d.behavior().menu_placement == .global_ {
		if idx := d.window_index(d.focus) {
			menu := system_window_menu(d.windows[idx].title, d.behavior().shade_enabled)
			menu_x := taskbar_padding + start_button_width + 10
			children << d.app_menu_slot(menu, menu_x)
		}
	}

	// Launcher strip (Blue spec E4): a pinned-app strip of icon_tiles placed
	// after the system menu (the BeOS Deskbar arrangement). Rendered only when
	// the resolved shell pins apps, so shells without a launcher are unchanged.
	pins := d.shell().launcher_pins
	if pins.len > 0 {
		launch_x := taskbar_padding + start_button_width + 10
		children << d.launcher_element(pins, launch_x)
	}

	// Trailing: the clock, right-aligned in a reserved area.
	clock_w := taskbar_clock_width
	children << ui2.label('topbar.clock', d.taskbar_clock_time, ui2.rect(f64(width - taskbar_padding - clock_w), 4, f64(clock_w), f64(top_bar_height - 6)), ui2.TextStyle{
		color: theme.taskbar_text_active
		size: 14
		bold: true
		align: .right
	})

	// Tray (Blue spec E5): status icons in the trailing slot, left of the
	// clock. Rendered only when the resolved shell registers items, so an empty
	// tray occupies no space and does not overlap the clock. Notifications are a
	// deferred tray extension (GAP-13).
	tray := d.shell().tray_items
	if tray.len > 0 {
		tray_w := tray.len * (tray_icon_size + tray_gap) - tray_gap
		tray_x := width - taskbar_padding - clock_w - tray_pad - tray_w
		children << d.tray_element(tray, tray_x)
	}

	// A hairline along the bottom edge separates the bar from the desktop.
	children << ui2.view('topbar.edge', ui2.rect(0, f64(top_bar_height - 1), f64(width), 1), ui2.BoxStyle{
		bg: theme.taskbar_edge
	}, [])

	return ui2.view('topbar', ui2.rect(0, 0, f64(width), f64(top_bar_height)), ui2.BoxStyle{
		bg: theme.taskbar_bg
	}, children)
}

// app_menu_slot renders a menu's top-level titles as a horizontal menu bar in
// the top panel (Blue spec F2, global placement). The slot's own id is stable
// (top_bar_app_menu_id); each title carries the menu's title text. Clicking the
// slot opens the focused window's system menu (reusing the window-menu host).
fn (d &Desktop) app_menu_slot(menu Menu, x int) ui2.Element {
	theme := d.theme()
	mut children := frame_elements(1)
	// A single leading title (the window/app name). Per-app submenus (F4) are
	// deferred; the first cut surfaces the window menu behind one title.
	label_w := 160
	children << ui2.label('', menu.title, ui2.rect(6, 4, f64(label_w), f64(top_bar_height - 6)), ui2.TextStyle{
		color: theme.taskbar_text_active
		size: 13
		bold: true
		align: .left
	})
	return ui2.clickable_view(top_bar_app_menu_id, ui2.rect(f64(x), 0, f64(label_w + 12), f64(top_bar_height)), ui2.BoxStyle{
		bg: if d.hover == top_bar_app_menu_id { theme.accent_dim } else { u32(0) }
		transparent: d.hover != top_bar_app_menu_id
		radius: 4
	}, children)
}

// launcher_element renders the pinned-app launcher strip (Blue spec E4) as a
// horizontal run of compact icon_tiles starting at `x`. Each tile is one pin
// (an index into available_apps) and carries that app's shortcut action id, so
// clicking it launches the app exactly as the wallpaper shortcut does. The
// strip's own view id is stable (top_bar_launcher_id) so hit routing and tests
// can find it. Tiles use B's shared icon_tile renderer (no private renderer).
fn (d &Desktop) launcher_element(pins []int, x int) ui2.Element {
	theme := d.theme()
	style := IconTileStyle{
		label: theme.taskbar_text_active
		hover: theme.taskbar_text_active
		panel: theme.accent_dim
	}
	tile := top_bar_height - 4
	gap := 4
	mut children := frame_elements(pins.len)
	mut tx := 0
	for pin in pins {
		if pin < 0 || pin >= available_apps.len {
			continue
		}
		factory := &available_apps[pin]
		action := app_shortcut_actions[pin]
		children << icon_tile_ex(action, factory.icon, factory.title, ui2.rect(f64(tx), 2, f64(tile), f64(tile)), d.hover == action, style, false, true)
		tx += tile + gap
	}
	width := if tx > 0 { tx - gap } else { 0 }
	return ui2.view(top_bar_launcher_id, ui2.rect(f64(x), 0, f64(width), f64(top_bar_height)), ui2.BoxStyle{
		transparent: true
	}, children)
}

// tray_element renders the status tray (Blue spec E5): a run of status items in
// the trailing slot starting at `x`, left of the clock. Each item is a small
// labelled cell with a stable id ('tray.<kind>'); the first cut shows status
// text (a battery/wifi glyph set is later). Notifications are a deferred tray
// extension (GAP-13). An empty tray is never rendered (the caller gates on len),
// so the tray occupies no space by default.
fn (d &Desktop) tray_element(items []TrayStatus, x int) ui2.Element {
	theme := d.theme()
	mut children := frame_elements(items.len)
	mut tx := 0
	for item in items {
		id, glyph := match item {
			.battery { 'tray.battery', 'BAT' }
			.wifi { 'tray.wifi', 'WiFi' }
		}
		children << ui2.label(id, glyph, ui2.rect(f64(tx), 5, f64(tray_icon_size), f64(top_bar_height - 8)), ui2.TextStyle{
			color: theme.taskbar_text_active
			size: 10
			align: .center
		})
		tx += tray_icon_size + tray_gap
	}
	width := if tx > 0 { tx - tray_gap } else { 0 }
	return ui2.view(top_bar_tray_id, ui2.rect(f64(x), 0, f64(width), f64(top_bar_height)), ui2.BoxStyle{
		transparent: true
	}, children)
}
