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

// top_bar_element builds the top panel. Item ids are stable so hit routing and
// tests can find them:
//   'topbar'            the panel view
//   'taskbar.system'    the leading system-menu button
//   'topbar.clock'      the trailing clock label
fn (d &Desktop) top_bar_element() ui2.Element {
	theme := d.theme()
	width := d.canvas.width

	mut children := frame_elements(3)

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
