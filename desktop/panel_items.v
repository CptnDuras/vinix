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

	mut children := frame_elements(4)

	// Leading: the system menu (the Blue leaf / Apple-style menu). Reuses the
	// start-toggle action so clicking it opens the system menu host.
	children << ui2.button_with_image(top_bar_action_system, '', 'builtin:vinix',
		ui2.rect(f64(taskbar_padding), 2, f64(start_button_width), f64(top_bar_height - 4)),
		ui2.BoxStyle{
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

	// Trailing: the clock, right-aligned in a reserved area.
	clock_w := taskbar_clock_width
	children << ui2.label('topbar.clock', d.taskbar_clock_time, ui2.rect(f64(width - taskbar_padding - clock_w),
		4, f64(clock_w), f64(top_bar_height - 6)), ui2.TextStyle{
		color: theme.taskbar_text_active
		size: 14
		bold: true
		align: .right
	})

	// A hairline along the bottom edge separates the bar from the desktop.
	children << ui2.view('topbar.edge', ui2.rect(0, f64(top_bar_height - 1), f64(width), 1),
		ui2.BoxStyle{
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
	children << ui2.label('', menu.title, ui2.rect(6, 4, f64(label_w), f64(top_bar_height - 6)),
		ui2.TextStyle{
		color: theme.taskbar_text_active
		size:  13
		bold:  true
		align: .left
	})
	return ui2.clickable_view(top_bar_app_menu_id, ui2.rect(f64(x), 0, f64(label_w + 12),
		f64(top_bar_height)), ui2.BoxStyle{
		bg:          if d.hover == top_bar_app_menu_id { theme.accent_dim } else { u32(0) }
		transparent: d.hover != top_bar_app_menu_id
		radius:      4
	}, children)
}
