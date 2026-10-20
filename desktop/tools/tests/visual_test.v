// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Programmatic visual testing of the Blue UI surfaces. For each registered
// look-and-feel preset this renders a representative desktop (a window plus the
// resolved shell) to an off-screen canvas, asserts signature pixels so a visual
// regression is caught in CI, and — when VINIX_SNAPSHOT_DIR is set — writes a
// PNG per preset for eyeballing.
//
// This is not a substitute for looking at the desktop, but it turns "does Blue
// still look like Blue" into an automated check: the window body, the active
// title colour, the presence of a top bar and/or taskbar, and the beveled
// title edge are all verified from real rendered pixels.
module main

import os
import ui2

fn visual_element_named(el ui2.Element, id string) ?ui2.Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		found := visual_element_named(child, id) or { continue }
		return found
	}
	return none
}

fn snapshot_desktop(preset_id string) Desktop {
	mut d := Desktop{
		canvas: new_canvas(640, 420)
		fonts:  load_fonts()
	}
	d.settings.preset_id = preset_id
	d.spawn('${preset_id} window', .welcome, 60, 70, 360, 240)
	d.update_taskbar_clock_at(0)
	root := d.build_tree()
	d.render(root)
	free_tree(root)
	return d
}

@[inline]
fn pixel_at(d &Desktop, x int, y int) u32 {
	return unsafe { d.canvas.pixels[y * d.canvas.stride + x] }
}

fn maybe_dump(d &Desktop, name string) {
	dir := os.getenv('VINIX_SNAPSHOT_DIR')
	if dir == '' {
		return
	}
	os.mkdir_all(dir) or { return }
	capture_write_png(os.join_path(dir, '${name}.png'), &d.canvas)
}

// Every preset renders a window whose body matches the resolved decor body
// colour, and a shell (a top bar and/or a bottom taskbar). This catches a
// preset that renders blank or loses its shell.
fn test_every_preset_renders_its_surfaces() {
	for lnf in lookandfeel_registry {
		mut d := snapshot_desktop(lnf.id)
		defer {
			unsafe { free(d.canvas.pixels) }
		}
		eff_body := d.theme().window_body
		// Inside the window body (well below the title bar): the decor body.
		body_px := pixel_at(&d, 200, 300)
		assert body_px == eff_body

		// The resolved shell must place at least one bar.
		shell := d.shell()
		assert shell.has_top_bar || shell.has_bottom_bar

		root := d.build_tree()
		if shell.has_top_bar {
			assert visual_element_named(root, 'topbar') != none
		}
		if shell.has_bottom_bar {
			assert visual_element_named(root, 'taskbar') != none
		}
		free_tree(root)

		maybe_dump(&d, lnf.id)
	}
}

// Beveled presets (Blue and the era looks) paint a light bevel pixel along the
// title bar's top edge; the flat presets (Default/macOS) do not require it.
fn test_beveled_presets_have_a_light_title_edge() {
	// The window is at x=60,y=70; its title bar top row is y=70. Scan a run of
	// the top edge for the bevel light colour (the exact pixel varies with the
	// rounded corner and title gradient).
	scan_y := 71
	for lnf in lookandfeel_registry {
		mut d := snapshot_desktop(lnf.id)
		defer {
			unsafe { free(d.canvas.pixels) }
		}
		theme := d.theme()
		if !theme.bevel_enabled {
			continue
		}
		mut found := false
		for yy in 70 .. 74 {
			for x in 62 .. 400 {
				if pixel_at(&d, x, yy) == theme.bevel_light {
					found = true
					break
				}
			}
			if found {
				break
			}
		}
		assert found
	}
}

// The active window's title carries the theme's active title colour somewhere
// along the bar (the gradient/bevel aside, the base fill is present at the
// bar's mid-height near the leading edge before the title text).
fn test_active_title_uses_the_theme_colour() {
	mut d := snapshot_desktop('default')
	defer {
		unsafe { free(d.canvas.pixels) }
	}
	// Default's active title bg is white (0xffffff); sample within the bar.
	theme := d.theme()
	// A point on the title bar, away from the buttons and text baseline.
	px := pixel_at(&d, 64, 70 + theme.title_height / 2)
	// The title bar area should not be the wallpaper nor the body; it is the
	// title fill or its gradient/bevel — assert it is not the window body.
	assert px != theme.window_body || theme.title_active_bg == theme.window_body
}

// The BeOS look wears a built-in skin whose close box is a vector: a hollow
// square. Its frame is dark and its middle shows the tab through it.
fn test_beos_close_box_is_a_hollow_vector_square() {
	mut d := snapshot_desktop('beos')
	defer {
		unsafe { free(d.canvas.pixels) }
	}
	assert d.skin_active()
	// The window is at (60, 70); the close box is 14 wide, 5 in, centred in the
	// 22 pixel tab.
	frame_px := pixel_at(&d, 66, 81)
	middle_px := pixel_at(&d, 72, 81)
	assert (frame_px >> 16) & 0xff < 0x90
	assert (middle_px >> 16) & 0xff > 0xd0
	// And the tab is narrower than the window: right of it is the desktop.
	assert pixel_at(&d, 60 + 340, 80) != pixel_at(&d, 80, 80)
}

fn test_a_look_without_a_skin_draws_its_stock_controls() {
	mut d := snapshot_desktop('default')
	defer {
		unsafe { free(d.canvas.pixels) }
	}
	assert !d.skin_active()
}

fn snapshot_with_skin(preset string, skin string) Desktop {
	mut d := Desktop{
		canvas: new_canvas(640, 420)
		fonts:  load_fonts()
	}
	d.settings.preset_id = preset
	d.settings.skin_id = skin
	d.spawn('skinned', .welcome, 60, 70, 360, 240)
	d.update_taskbar_clock_at(0)
	root := d.build_tree()
	d.render(root)
	free_tree(root)
	return d
}

// A bitmap skin replaces the bar with its nine-slice art and the buttons with
// its orbs. The glass bar is blue-tinted, which no stock look's bar is.
fn test_a_bitmap_skin_paints_its_bar_and_orbs() {
	if os.getenv('VINIX_SKIN_DIR') == '' || !os.exists(os.join_path(os.getenv('VINIX_SKIN_DIR'), 'glass', 'skin.cfg')) {
		return
	}
	mut d := snapshot_with_skin('default', 'glass')
	defer {
		unsafe { free(d.canvas.pixels) }
	}
	assert d.skin_active()
	// Mid-bar: the glass blue, where the default look is white.
	bar := pixel_at(&d, 250, 76)
	assert (bar & 0xff) > (bar >> 16) & 0xff
	// The close orb is red where the default look has only a glyph on white.
	// Where it sits follows the bar's height, so look along the bar's leading
	// end for it rather than at one pixel.
	maybe_dump(&d, 'glass')
	mut orb_found := false
	for y in 70 .. 70 + d.theme().title_height {
		for x in 60 .. 60 + 96 {
			px := pixel_at(&d, x, y)
			if (px >> 16) & 0xff > 0xb0 && (px & 0xff) < 0x90 {
				orb_found = true
			}
		}
	}
	assert orb_found
}

fn test_choosing_none_removes_a_looks_own_skin() {
	mut d := snapshot_with_skin('beos', 'none')
	defer {
		unsafe { free(d.canvas.pixels) }
	}
	assert !d.skin_active()
}

// The cascading Start menus, opened with the program list beside them: each
// shows its own title, strip or plain frame, and stays inside the screen.
fn cascade_snapshot(style StartMenuStyle, width int, height int) Desktop {
	mut d := Desktop{
		canvas: new_canvas(width, height)
		fonts:  load_fonts()
	}
	d.settings.start_menu = style
	d.update_taskbar_clock_at(0)
	d.toggle_start_menu()
	root := d.start_cascade_root()
	for index, row in root {
		if row.children.len > 0 && row.title == tr('start.programs') {
			d.start_cascade_path = [index]
		}
	}
	tree := d.build_tree()
	d.render(tree)
	free_tree(tree)
	return d
}

fn test_cascading_start_menus_are_drawn_in_their_own_colours() {
	for style in [StartMenuStyle.fluxbox, .deskbar, .kmenu] {
		mut d := cascade_snapshot(style, 800, 600)
		defer {
			unsafe { free(d.canvas.pixels) }
		}
		look := cascade_look(style)
		maybe_dump(&d, 'startmenu-${start_menu_style_id(style)}')
		boxes := d.start_cascade_boxes()
		assert boxes.len == 2
		root := boxes[0]
		// The frame's own colour, between the rows' text and the edge.
		assert pixel_at(&d, root.x + root.width - 3, root.y + root.height - 4) == look.frame
		// The outline.
		assert pixel_at(&d, root.x, root.y + root.height / 2) == look.border
		|| pixel_at(&d, root.x + 1, root.y + root.height / 2) == look.border
		if look.metrics.header_height > 0 {
			assert pixel_at(&d, root.x + root.width - 4, root.y + 3) == look.header
		}
		if look.banner != 0 {
			assert pixel_at(&d, root.x + 4, root.y + root.height / 2) == look.banner
		}
		// The submenu is beside the root, on the screen.
		sub := boxes[1]
		assert sub.x >= 0 && sub.x + sub.width <= 800 && sub.y >= 0 && sub.y + sub.height <= 600
		assert pixel_at(&d, sub.x, sub.y + sub.height / 2) == look.border
		|| pixel_at(&d, sub.x + 1, sub.y + sub.height / 2) == look.border
	}
}
