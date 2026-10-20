// SPDX-License-Identifier: GPL-2.0-or-later
module main

import ui2

fn cascade_find_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := cascade_find_element(child, id) {
			return found
		}
	}
	return none
}

fn cascade_desktop(style StartMenuStyle) &Desktop {
	mut d := &Desktop{
		canvas: Canvas{
			width: 1024
			height: 768
		}
	}
	d.settings.start_menu = style
	return d
}

fn test_the_style_follows_the_look_unless_chosen() {
	mut d := cascade_desktop(.follow_look)
	d.settings.preset_id = 'beos'
	assert d.start_menu_style() == .deskbar
	d.settings.preset_id = 'haiku'
	assert d.start_menu_style() == .deskbar
	d.settings.preset_id = 'win31'
	assert d.start_menu_style() == .windows
	d.settings.start_menu = .fluxbox
	d.settings.preset_id = 'beos'
	assert d.start_menu_style() == .fluxbox
	assert d.start_menu_cascades()
	d.settings.start_menu = .windows
	assert !d.start_menu_cascades()
}

fn test_a_cascading_menu_opens_with_its_root_only() {
	for style in [StartMenuStyle.fluxbox, .deskbar] {
		mut d := cascade_desktop(style)
		d.toggle_start_menu()
		assert d.start_menu_open
		assert d.start_cascade_path.len == 0
		begin_frame_elements()
		tree := d.start_menu_element()
		assert cascade_find_element(tree, cascade_row_id(0, 0)) != none
		assert cascade_find_element(tree, 'start.cas.box.0') != none
		assert cascade_find_element(tree, 'start.cas.box.1') == none
		// The Windows menu's own panes are not there.
		assert cascade_find_element(tree, 'start.programs') == none
	}
}

fn test_the_boxes_stay_on_the_screen() {
	for style in [StartMenuStyle.fluxbox, .deskbar] {
		for width in [320, 640, 1024]! {
			mut d := Desktop{
				canvas: Canvas{
					width: width
					height: 480
				}
			}
			d.settings.start_menu = style
			d.toggle_start_menu()
			// Open the program list, the biggest submenu there is.
			root := d.start_cascade_root()
			mut programs := -1
			for index, row in root {
				if row.children.len > 0 && row.title == tr('start.programs') {
					programs = index
				}
			}
			assert programs >= 0
			d.start_cascade_path = [programs]
			for box in d.start_cascade_boxes() {
				assert box.x >= 0 && box.y >= 0
				// A box wider than the screen can only start at its edge.
				assert box.x + box.width <= width || (box.width > width && box.x == 0)
				assert box.y + box.height <= 480
			}
		}
	}
}

fn test_resting_on_a_parent_opens_it_and_a_plain_row_closes_it() {
	mut d := cascade_desktop(.fluxbox)
	d.toggle_start_menu()
	root := d.start_cascade_root()
	mut programs := -1
	mut plain := -1
	for index, row in root {
		if row.separator {
			continue
		}
		if row.children.len > 0 && programs < 0 {
			programs = index
		}
		if row.children.len == 0 && plain < 0 {
			plain = index
		}
	}
	d.set_hover(cascade_row_id(0, programs))
	d.update_start_menu_hover()
	assert d.start_cascade_path == [programs]
	begin_frame_elements()
	assert cascade_find_element(d.start_menu_element(), 'start.cas.box.1') != none
	d.set_hover(cascade_row_id(0, plain))
	d.update_start_menu_hover()
	assert d.start_cascade_path.len == 0
}

fn test_clicking_a_row_runs_its_action_and_closes_the_menu() {
	mut d := cascade_desktop(.deskbar)
	d.toggle_start_menu()
	root := d.start_cascade_root()
	mut about := -1
	for index, row in root {
		if row.action == action_start_welcome {
			about = index
		}
	}
	assert about >= 0
	d.handle_start_action(cascade_row_id(0, about))
	assert !d.start_menu_open
	assert d.windows.len == 1
}

fn test_clicking_a_parent_keeps_the_menu_open() {
	mut d := cascade_desktop(.deskbar)
	d.toggle_start_menu()
	root := d.start_cascade_root()
	mut parent := -1
	for index, row in root {
		if row.children.len > 0 {
			parent = index
			break
		}
	}
	d.handle_start_action(cascade_row_id(0, parent))
	assert d.start_menu_open
	assert d.start_cascade_path == [parent]
	// A click on something that is not a row changes nothing.
	d.handle_start_action(cascade_prefix + 'x.y')
	assert d.start_menu_open && d.start_cascade_path == [parent]
}

fn test_closing_and_reopening_starts_from_the_root() {
	mut d := cascade_desktop(.fluxbox)
	d.toggle_start_menu()
	d.start_cascade_path = [3]
	d.close_start_menu()
	assert d.start_cascade_path.len == 0
	d.toggle_start_menu()
	assert d.start_cascade_path.len == 0
}

fn test_typing_does_not_search_a_cascading_menu() {
	mut d := cascade_desktop(.fluxbox)
	d.toggle_start_menu()
	d.start_menu_key_input('calc')
	assert d.start_menu_query.len == 0
	d.start_menu_key_input('\x1b')
	assert !d.start_menu_open
}

fn test_the_rows_are_built_again_only_when_the_history_changes() {
	mut d := cascade_desktop(.fluxbox)
	d.toggle_start_menu()
	first := d.start_cascade_root()
	built := d.start_cascade_built
	assert d.start_cascade_root().len == first.len
	assert d.start_cascade_built == built
	d.recent_programs = [1, 2]
	d.start_cascade_root()
	assert d.start_cascade_built != built
}

fn test_the_two_styles_hold_different_roots() {
	fluxbox := cascade_desktop(.fluxbox).start_cascade_entries(.fluxbox)
	deskbar := cascade_desktop(.deskbar).start_cascade_entries(.deskbar)
	assert fluxbox.len > 0 && deskbar.len > 0
	assert fluxbox[0].title != deskbar[0].title
	// Fluxbox shows no icons; the Deskbar menu does.
	assert fluxbox[0].icon == ''
	mut icons := 0
	for row in deskbar {
		if row.icon.len > 0 {
			icons++
		}
	}
	assert icons > 0
	// Both end with the session.
	assert fluxbox.last().action == action_start_shutdown
	assert deskbar.last().action == action_start_shutdown
}

fn test_every_program_is_reachable() {
	d := cascade_desktop(.fluxbox)
	programs := d.cascade_programs(false)
	assert programs.len == desktop_menu_count()
	for row in programs {
		assert row.action.starts_with('start.')
		assert row.title.len > 0
	}
}

fn test_the_k_menu_has_its_banner() {
	mut d := cascade_desktop(.kmenu)
	d.toggle_start_menu()
	begin_frame_elements()
	tree := d.start_menu_element()
	assert cascade_find_element(tree, 'start.cas.banner') != none
	// The strip is the root box's alone.
	d.start_cascade_path = [0]
	begin_frame_elements()
	assert cascade_find_element(d.start_menu_element(), 'start.cas.box.1') != none
	boxes := d.start_cascade_boxes()
	shape := cascade_shape(d.start_cascade_root(), 0, cascade_look_kmenu.metrics, 1000)
	assert shape.banner == cascade_look_kmenu.metrics.banner && boxes[0].width == shape.width
}
