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
const top_bar_menu_width = 172
const top_bar_item_max_width = 150

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
	shell := d.shell()
	item_h := top_bar_height - 4

	mut children := frame_elements(16)

	// Leading: the system menu (the Blue leaf / Apple-style menu). Reuses the
	// start-toggle action so clicking it opens the system menu host.
	children << ui2.button_with_image(top_bar_action_system, '', 'builtin:vinix', ui2.rect(f64(taskbar_padding), 2, f64(start_button_width), f64(item_h)), ui2.BoxStyle{
		bg: if d.start_menu_open || d.hover == top_bar_action_system {
			theme.accent
		} else {
			theme.accent_dim
		}
		radius: 4
	}, ui2.TextStyle{
		color: theme.taskbar_text_active
	})
	mut left_x := taskbar_padding + start_button_width + 10

	// Global app-menu slot (Blue spec F2): when the resolved menu_placement is
	// .global, the focused window's menu is hosted here in the top bar (the
	// Platinum / GNOME arrangement). The Shell owns only the slot; the menu
	// content is F's system_window_menu of the focused window. The slot targets
	// this position — F fills it — which keeps the E↔F graph acyclic.
	global_menu := d.behavior().menu_placement == .global_
	if global_menu {
		if idx := d.window_index(d.focus) {
			menu := system_window_menu(d.windows[idx].title, d.behavior().shade_enabled)
			children << d.app_menu_slot(menu, left_x)
			left_x += top_bar_menu_width + 10
		}
	}

	// Launcher strip (Blue spec E4): a pinned-app strip of icon_tiles placed
	// after the system menu (the BeOS Deskbar arrangement). Rendered only when
	// the resolved shell pins apps, so shells without a launcher are unchanged.
	pins := shell.launcher_pins
	if pins.len > 0 {
		launcher := d.launcher_element(pins, left_x)
		left_x += int(launcher.frame.width) + 10
		children << launcher
	}

	// Trailing: the clock, right-aligned in a reserved area.
	clock_w := taskbar_clock_width
	clock_x := width - taskbar_padding - clock_w
	children << ui2.label('topbar.clock', d.taskbar_clock_time, ui2.rect(f64(clock_x), 4, f64(clock_w), f64(top_bar_height - 6)), ui2.TextStyle{
		color: theme.taskbar_text_active
		size: 14
		bold: true
		align: .right
	})
	mut right_x := clock_x - 8

	// Tray (Blue spec E5): the status icons, left of the clock. A shell without
	// a bottom bar has nowhere else for them, so it shows the whole tray; one
	// that registers its own items shows those. An empty tray takes no space.
	if shell.tray_items.len > 0 || !shell.has_bottom_bar {
		tray := d.tray_element(shell.tray_items, right_x)
		if tray.children.len > 0 {
			right_x = int(tray.frame.x) - 8
			children << tray
		}
	}

	// The workspace pager, which the bottom bar would otherwise carry.
	if !shell.has_bottom_bar {
		pager_w := workspace_count * workspace_button_width + (workspace_count - 1) * workspace_button_gap
		pager_x := right_x - pager_w
		if pager_x > left_x + 80 {
			for workspace in 0 .. workspace_count {
				id := workspace_action_ids[workspace]
				active := workspace == d.current_workspace
				occupied := d.workspace_window_count(workspace) > 0
				children << ui2.button(id, workspace_labels[workspace], ui2.rect(f64(pager_x +
					workspace * (workspace_button_width + workspace_button_gap)), 2,
					f64(workspace_button_width), f64(item_h)), ui2.BoxStyle{
					bg:     if active {
						theme.accent
					} else if d.hover == id {
						theme.taskbar_item_hover
					} else {
						theme.taskbar_item_bg
					}
					radius: 4
				}, ui2.TextStyle{
					color: if active || occupied { theme.taskbar_text_active } else { theme.taskbar_muted }
					size:  12
					bold:  active
					align: .center
				})
			}
			right_x = pager_x - 8
		}
	}

	// The window list, when the shell wants one and no bottom bar holds it. A
	// global menu takes this room in the Mac arrangement, and shows the focused
	// window's name itself.
	if shell.has_window_list && !shell.has_bottom_bar && !global_menu && right_x > left_x + 60 {
		entries := d.taskbar_entries()
		defer {
			unsafe { entries.free() }
		}
		item_w := mini(d.taskbar_item_width(entries.len, left_x, right_x), top_bar_item_max_width)
		mut x := left_x
		for entry in entries {
			if x + item_w > right_x {
				break
			}
			d.taskbar_entry_elements(mut children, entry, x, 2, item_w, item_h, false, false)
			x += item_w + taskbar_item_gap
		}
	}

	// A hairline along the bottom edge separates the bar from the desktop.
	children << ui2.view('topbar.edge', ui2.rect(0, f64(top_bar_height - 1), f64(width), 1), ui2.BoxStyle{
		bg: theme.taskbar_edge
	}, [])

	return ui2.view('topbar', ui2.rect(0, 0, f64(width), f64(top_bar_height)), ui2.BoxStyle{
		bg: theme.taskbar_bg
	}, children)
}

fn mini(a int, b int) int {
	return if a < b { a } else { b }
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
	label_w := top_bar_menu_width - 12
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

// tray_element renders the status tray (Blue spec E5) as real tray icons, ending
// at `right` and growing leftwards, the same icons and actions the taskbar's
// tray has, so their flyouts work. `wanted` limits it to the statuses a shell
// registers; empty means every icon the tray shows. An empty tray has no
// children and a zero width.
fn (d &Desktop) tray_element(wanted []TrayStatus, right int) ui2.Element {
	mut children := frame_elements(tray_item_count + 1)
	mut items := []int{}
	for index in 0 .. tray_item_count {
		item := tray_item_from_index(index)
		if !d.tray.on_taskbar(item) {
			continue
		}
		if wanted.len > 0 {
			status := match item {
				.network { TrayStatus.wifi }
				.battery { TrayStatus.battery }
				else { continue }
			}
			if status !in wanted {
				continue
			}
		}
		items << index
	}
	width := items.len * tray_icon_width
	x := right - width
	mut at := 0
	for index in items {
		item := tray_item_from_index(index)
		children << d.tray_icon_element(tray_icon_actions[index], d.tray_glyph(item), at, 2,
			tray_icon_width, top_bar_height - 4, d.tray.flyout == tray_flyout_for(item))
		at += tray_icon_width
	}
	return ui2.view(top_bar_tray_id, ui2.rect(f64(x), 0, f64(width), f64(top_bar_height)), ui2.BoxStyle{
		transparent: true
	}, children)
}
