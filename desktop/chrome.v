// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// The desktop's side of the window chrome model (Blue spec B5): resolving a
// ChromeSpec for the current theme and naming a widget's element and glyph.
module main

import ui2

// chrome_spec is the active look's chrome with its widget list filled in. A
// theme that names no widgets gets the stock three, from the button look and
// side the user has chosen.
fn (d &Desktop) chrome_spec() ChromeSpec {
	theme := d.theme()
	spec := theme.chrome
	if spec.widgets.len > 0 {
		return spec
	}
	return ChromeSpec{
		...spec
		widgets: stock_widgets(theme.button_look == .traffic, d.settings.button_side == .left)
	}
}

// widget_id is the element id of a window's widget. The ids are built when the
// window opens, so a frame does not allocate them.
fn (d &Desktop) widget_id(window &Window, action WidgetAction) string {
	return match action {
		.close { window.id_close }
		.minimize { window.id_minimize }
		.maximize { window.id_maximize }
		.shade { window.id_shade }
		.menu { window.id_menu }
	}
}

// widget_glyph names the mark drawn on a widget.
fn (d &Desktop) widget_glyph(spec WidgetSpec, maximized bool) string {
	disc := spec.shape == .disc
	return match spec.action {
		.close { if disc { 'builtin:traffic_close' } else { 'builtin:close' } }
		.minimize { if disc { 'builtin:traffic_minimize' } else { 'builtin:minimize' } }
		// Catalina calls this the zoom control. Its mark stays a plus while the
		// standard window frame toggles between its two sizes.
		.maximize { if disc { 'builtin:zoom' } else if maximized { 'builtin:restore' } else { 'builtin:maximize' } }
		.shade { 'builtin:shade' }
		.menu { 'builtin:window_menu' }
	}
}

// title_button is a stock widget named by its glyph: the form the title bar
// had before widgets were data, kept for callers that place one control by hand.
fn (d &Desktop) title_button(id string, glyph string, x int, active bool, set_hovered bool) ui2.Element {
	theme := d.theme()
	action := if glyph.ends_with('close') {
		WidgetAction.close
	} else if glyph.ends_with('minimize') {
		WidgetAction.minimize
	} else {
		WidgetAction.maximize
	}
	spec := WidgetSpec{
		action: action
		shape: if theme.button_look == .traffic { WidgetShape.disc } else { WidgetShape.square }
	}
	return d.title_widget(spec, id, glyph, x, theme.button_size, theme.title_height, active,
		set_hovered)
}
