// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Three KDE 2 era window styles: the stock KDE 2 decoration, Quartz and
// Keramik. A style of the day was Qt code and a pile of pixmaps, so these are
// painted from the same few numbers every other look uses (a gradient, a
// bevel, the controls and where they sit) rather than converted from those
// files. All three wear the K menu, which a look may set and the user may
// change on the Start menu page of Settings > Appearance.
module main

// KDE 2: a deep blue gradient title that reads left to right, white lettering,
// a small button for the window menu on the left and the minimise, maximise and
// close buttons on the right, each a raised square on the grey frame.
const theme_kde2 = Theme{
	name: 'KDE 2'
	start_menu: .kmenu
	window_body: 0xdcdcdc
	window_edge: 0x4a4a4a
	window_radius: 0
	shadow_alpha: 60
	title_height: 22
	title_active_bg: 0x1f3f8a
	title_active_bg2: 0x6f95d8
	title_inactive_bg: 0x9a9a9a
	title_inactive_bg2: 0xc4c4c4
	title_divider: 0x4a4a4a
	title_text_active: 0xffffff
	title_text_inactive: 0x303030
	title_align: .left
	title_bold: true
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'kde2-buttons'
		widgets: [
			WidgetSpec{ action: .menu, anchor: .leading },
			WidgetSpec{ action: .close, anchor: .trailing },
			WidgetSpec{ action: .maximize, anchor: .trailing },
			WidgetSpec{ action: .minimize, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xffffff
	bevel_dark: 0x5a5a5a
	bevel_width: 1
	button_size: 16
	button_gap: 2
	button_inset: 3
	button_hover: 0xeeeeee
	button_close_hover: 0xeeeeee
	button_face: 0xdcdcdc
	button_edge: 0x4a4a4a
	glyph_color: 0x101010
	glyph_on_close: 0x101010
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x888888
	dock: false
	dock_bg: 0xdcdcdc
	dock_radius: 0
	dock_padding: 4
	taskbar_bg: 0xdcdcdc
	taskbar_edge: 0xffffff
	taskbar_text: 0x101010
	taskbar_text_active: 0xffffff
	taskbar_muted: 0x606060
	taskbar_item_bg: 0xdcdcdc
	taskbar_item_hover: 0xeeeeee
	taskbar_item_active: 0x3d63a8
	accent: 0x3d63a8
	accent_dim: 0x7e8fb0
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x1f3f8a
}

// Quartz: a pale blue title that brightens to the right, dark lettering centred
// in it, and raised round-cornered buttons on both sides of it.
const theme_quartz = Theme{
	name: 'Quartz'
	start_menu: .kmenu
	window_body: 0xe6e9ef
	window_edge: 0x5d6b86
	window_radius: 3
	shadow_alpha: 60
	title_height: 24
	title_active_bg: 0x7aa2e6
	title_active_bg2: 0xc9dcf8
	title_inactive_bg: 0xc8ccd6
	title_inactive_bg2: 0xe3e6ec
	title_divider: 0x5d6b86
	title_text_active: 0x10204a
	title_text_inactive: 0x505868
	title_align: .center
	title_bold: false
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'kde2-buttons'
		widgets: [
			WidgetSpec{ action: .menu, anchor: .leading },
			WidgetSpec{ action: .shade, anchor: .leading },
			WidgetSpec{ action: .close, anchor: .trailing },
			WidgetSpec{ action: .maximize, anchor: .trailing },
			WidgetSpec{ action: .minimize, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xffffff
	bevel_dark: 0x7d8aa6
	bevel_width: 1
	button_size: 16
	button_gap: 3
	button_inset: 4
	button_hover: 0xf4f8ff
	button_close_hover: 0xffd9d4
	button_face: 0xdde6f6
	button_edge: 0x5d6b86
	glyph_color: 0x10204a
	glyph_on_close: 0x7a1010
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x9aa4b8
	dock: false
	dock_bg: 0xe6e9ef
	dock_radius: 0
	dock_padding: 4
	taskbar_bg: 0xdfe6f3
	taskbar_edge: 0xffffff
	taskbar_text: 0x10204a
	taskbar_text_active: 0x10204a
	taskbar_muted: 0x606a82
	taskbar_item_bg: 0xdfe6f3
	taskbar_item_hover: 0xf4f8ff
	taskbar_item_active: 0xaec6ee
	accent: 0x4f7bd0
	accent_dim: 0x8da6d6
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x2c4f9e
}

// Keramik: brushed silver from the top of the bar down, the title left-aligned
// in dark lettering, rounded corners and three round buttons on the right.
const theme_keramik = Theme{
	name: 'Keramik'
	start_menu: .kmenu
	window_body: 0xe9ebef
	window_edge: 0x8a909c
	window_radius: 7
	shadow_alpha: 80
	title_height: 26
	title_active_bg: 0xf3f4f7
	title_active_bg2: 0xbcc3d0
	title_inactive_bg: 0xe4e6ea
	title_inactive_bg2: 0xcdd1d8
	title_divider: 0x8a909c
	title_text_active: 0x1c2330
	title_text_inactive: 0x6a707c
	title_align: .left
	title_bold: true
	title_size: 12
	button_look: .traffic
	window_chrome: ChromeSpec{
		widgets: [
			WidgetSpec{ action: .menu, anchor: .leading },
			WidgetSpec{ action: .close, anchor: .trailing, shape: .disc },
			WidgetSpec{ action: .maximize, anchor: .trailing, shape: .disc },
			WidgetSpec{ action: .minimize, anchor: .trailing, shape: .disc },
		]
	}
	bevel_enabled: false
	bevel_light: 0xffffff
	bevel_dark: 0x8a909c
	bevel_width: 1
	button_size: 14
	button_gap: 5
	button_inset: 7
	button_hover: 0xffffff
	button_close_hover: 0xffffff
	button_face: 0xcdd3df
	button_edge: 0x8a909c
	glyph_color: 0x1c2330
	glyph_on_close: 0x1c2330
	traffic_close: 0xd9604c
	traffic_minimize: 0xc9a640
	traffic_zoom: 0x6aa84f
	traffic_idle: 0xa8aeb9
	dock: false
	dock_bg: 0xe9ebef
	dock_radius: 0
	dock_padding: 4
	taskbar_bg: 0xd4d9e2
	taskbar_edge: 0xffffff
	taskbar_text: 0x1c2330
	taskbar_text_active: 0x1c2330
	taskbar_muted: 0x636b78
	taskbar_item_bg: 0xd4d9e2
	taskbar_item_hover: 0xeceef3
	taskbar_item_active: 0xaab8d4
	accent: 0x4b78c8
	accent_dim: 0x8da0c6
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x3a557e
}
