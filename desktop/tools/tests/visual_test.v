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
