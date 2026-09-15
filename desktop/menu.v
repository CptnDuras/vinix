// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Menu system — the menu model (spec F1) and the system window menu (F3).
//
// A Menu is a pure data tree: items with a label, an action id, enabled/checked
// flags, an optional submenu, or a separator. It has NO dependency on the Shell
// or Window types (that one-way relationship is what keeps the E/F graph
// acyclic — the Shell's app_menu slot references this type, not vice versa).
// Rendering into a popup element tree lives in the ui2-coupled renderer; the
// model and its queries are unit-testable here.
module main

// MenuItem is one row. A separator has `separator: true` and no label/action.
struct MenuItem {
	label     string
	action    string // action id routed the usual way ('' for separators/parents)
	enabled   bool = true
	checked   bool
	separator bool
	submenu   []MenuItem
}

// Menu is a titled list of items (the title is used by an in-window menu bar or
// the global app-menu host).
struct Menu {
	title string
	items []MenuItem
}

// menu_visible_item_count counts the rows a menu would show, recursively
// including submenu rows (separators count as rows).
fn menu_visible_item_count(items []MenuItem) int {
	mut n := 0
	for it in items {
		n++
		if it.submenu.len > 0 {
			n += menu_visible_item_count(it.submenu)
		}
	}
	return n
}

// menu_find_action returns whether an action id exists anywhere in the tree
// (used to validate routing).
fn menu_has_action(items []MenuItem, action string) bool {
	for it in items {
		if it.action == action && !it.separator {
			return true
		}
		if it.submenu.len > 0 && menu_has_action(it.submenu, action) {
			return true
		}
	}
	return false
}

// ── F3: the system window menu ─────────────────────────────────────
//
// Every window has this menu regardless of preset, so the menu host is
// functional independent of per-app menus and window-handling actions have a
// menu path. Its actions invoke the D handlers via the usual action-id routing.

const menu_action_about = 'window.menu.about'
const menu_action_shade = 'window.menu.shade'
const menu_action_minimize = 'window.menu.minimize'
const menu_action_zoom = 'window.menu.zoom'
const menu_action_close = 'window.menu.close'

// system_window_menu builds the About / Shade / Minimize / Zoom / Close menu.
// `shade_enabled` disables the Shade row when the resolved Behavior turns shade
// off, so the menu reflects state (spec F3 acceptance (c)).
fn system_window_menu(title string, shade_enabled bool) Menu {
	return Menu{
		title: title
		items: [
			MenuItem{
				label:  'About ${title}'
				action: menu_action_about
			},
			MenuItem{
				separator: true
			},
			MenuItem{
				label:   'Shade'
				action:  menu_action_shade
				enabled: shade_enabled
			},
			MenuItem{
				label:  'Minimize'
				action: menu_action_minimize
			},
			MenuItem{
				label:  'Zoom'
				action: menu_action_zoom
			},
			MenuItem{
				separator: true
			},
			MenuItem{
				label:  'Close'
				action: menu_action_close
			},
		]
	}
}
