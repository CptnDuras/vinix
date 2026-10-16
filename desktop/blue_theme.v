// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Decorations — the flagship "Blue" Theme (spec B, G2).
//
// Blue's identity: the neutral cool gray ramp (blue_ramp) for every chrome
// surface, small square-ish corners, subtle structural depth, and the single
// reserved accent for the active title and selection. Period structure
// (bevels, restraint) rendered with the modern software renderer's anti-
// aliased type and soft shadow. Colors are taken from ramp roles, not literals,
// so retuning blue_ramp restyles Blue coherently.
module main

// Convenience: the ramp step for a role, as u32.
fn blue_(role SurfaceRole) u32 {
	return blue_ramp.surface(role)
}

// The flagship Blue theme. Where the existing Theme struct has no field for a
// concept Blue introduces (e.g. explicit bevels), Blue expresses it through the
// existing fields for now; the full EffectiveDecor migration (bevel_width,
// border_style) lands when the chrome builder reads EffectiveConfig directly.
const theme_blue = Theme{
	name: 'Blue'
	// Windows: light cool body, a mid-ramp edge, small corners, soft shadow.
	window_body:   blue_(.window_body)
	window_edge:   blue_(.edge)
	window_radius: 3
	shadow_alpha:  90
	// Title bar: the accent when focused (meaning: this window has focus),
	// a quiet panel gray when not. A faint vertical blend gives it depth
	// without a loud gradient.
	title_height:        30
	title_active_bg:     blue_ramp.accent
	title_active_bg2:    darken(blue_ramp.accent, 24)
	title_inactive_bg:   blue_(.panel)
	title_inactive_bg2:  blue_(.hover)
	title_divider:       blue_(.edge)
	title_text_active:   0xffffff
	title_text_inactive: blue_(.text_muted)
	title_centered:      false
	title_bold:          true
	title_size:          13
	// Buttons: flat glyphs with a ramp-derived hover; close goes accent-warm.
	button_look:        .flat
	// A subtle raised bevel on the chrome, from the ramp (structural depth
	// without loudness — Blue spec B3).
	bevel_enabled:      true
	bevel_light:        blue_ramp.steps[2]
	bevel_dark:         blue_ramp.steps[5]
	bevel_width:        1
	button_size:        22
	button_gap:         4
	button_inset:       8
	button_hover:       blue_(.hover)
	button_close_hover: 0xd6483b
	button_face:        blue_(.hover)
	button_edge:        blue_(.edge)
	glyph_color:        blue_(.text)
	glyph_on_close:     0xffffff
	// Traffic discs unused by Blue's flat look, but the struct needs them.
	traffic_close:    0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom:     0x28c840
	traffic_idle:     blue_(.edge)
	// A full-width taskbar (not a dock), drawn from the dark end of the ramp.
	dock:         false
	dock_bg:      blue_(.panel)
	dock_radius:  8
	dock_padding: 8
	taskbar_bg:          blue_(.shadow)
	taskbar_edge:        blue_ramp.steps[7]
	taskbar_text:        blue_ramp.steps[3]
	taskbar_text_active: 0xffffff
	taskbar_muted:       blue_(.text_muted)
	taskbar_item_bg:     blue_ramp.steps[7]
	taskbar_item_hover:  blue_ramp.steps[6]
	taskbar_item_active: blue_ramp.accent
	accent:              blue_ramp.accent
	accent_dim:          darken(blue_ramp.accent, 60)
	// Wallpaper shortcuts.
	shortcut_label: blue_(.window_body)
	shortcut_hover: 0xffffff
	shortcut_panel: blue_(.shadow)
}

// darken multiplies each channel of an 0xRRGGBB color toward black by
// `amount`/255, staying in the same hue — used for the title blend and dim
// accent so both derive from the accent rather than being fresh constants.
fn darken(color u32, amount int) u32 {
	r := int((color >> 16) & 0xff)
	g := int((color >> 8) & 0xff)
	b := int(color & 0xff)
	f := 255 - amount
	nr := u32(clamp_channel(r * f / 255))
	ng := u32(clamp_channel(g * f / 255))
	nb := u32(clamp_channel(b * f / 255))
	return (nr << 16) | (ng << 8) | nb
}

fn clamp_channel(v int) int {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return v
}
