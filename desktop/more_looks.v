// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// More looks, each a preset of what Settings > Appearance lets the user
// arrange: a title bar's shape, where its controls are, and the skin that draws
// them. They are registered in lookandfeel.v and mapped in preset_theme(); the
// controls' artwork is in skin_builtin.v.
module main

// NeXTSTEP: black title bars with white text, a miniaturise box at the left and a
//  close box at the right, hard two-pixel bevels in three greys.
const theme_nextstep = Theme{
	name: 'NeXTSTEP'
	window_body: 0xaaaaaa
	window_edge: 0x000000
	window_radius: 0
	shadow_alpha: 90
	title_height: 20
	title_active_bg: 0x000000
	title_active_bg2: 0x000000
	title_inactive_bg: 0xaaaaaa
	title_inactive_bg2: 0xaaaaaa
	title_divider: 0x000000
	title_text_active: 0xffffff
	title_text_inactive: 0x000000
	title_align: .left
	title_bold: false
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'next-gadgets'
		widgets: [
			WidgetSpec{ action: .minimize, anchor: .leading },
			WidgetSpec{ action: .close, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xffffff
	bevel_dark: 0x555555
	bevel_width: 2
	button_size: 16
	button_gap: 4
	button_inset: 4
	button_hover: 0x333333
	button_close_hover: 0x333333
	button_face: 0x000000
	button_edge: 0x000000
	glyph_color: 0xffffff
	glyph_on_close: 0xffffff
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x555555
	dock: false
	dock_bg: 0xaaaaaa
	dock_radius: 0
	dock_padding: 4
	taskbar_bg: 0xaaaaaa
	taskbar_edge: 0xffffff
	taskbar_text: 0x000000
	taskbar_text_active: 0xffffff
	taskbar_muted: 0x555555
	taskbar_item_bg: 0xaaaaaa
	taskbar_item_hover: 0xc8c8c8
	taskbar_item_active: 0x000000
	accent: 0x000000
	accent_dim: 0x555555
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x000000
}

// Amiga Workbench 3: a thin blue title bar with a close gadget at the left and
//  the zoom and depth gadgets at the right, black and white bevels, orange accent.
const theme_amiga = Theme{
	name: 'Amiga Workbench'
	window_body: 0xaaaaaa
	window_edge: 0x000000
	window_radius: 0
	shadow_alpha: 0
	title_height: 18
	title_active_bg: 0x0055aa
	title_active_bg2: 0x0055aa
	title_inactive_bg: 0xaaaaaa
	title_inactive_bg2: 0xaaaaaa
	title_divider: 0x000000
	title_text_active: 0xffffff
	title_text_inactive: 0x000000
	title_align: .left
	title_bold: false
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'amiga-gadgets'
		widgets: [
			WidgetSpec{ action: .close, anchor: .leading },
			WidgetSpec{ action: .shade, anchor: .trailing },
			WidgetSpec{ action: .maximize, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xffffff
	bevel_dark: 0x000000
	bevel_width: 1
	button_size: 14
	button_gap: 2
	button_inset: 2
	button_hover: 0x0066cc
	button_close_hover: 0x0066cc
	button_face: 0x0055aa
	button_edge: 0x000000
	glyph_color: 0xffffff
	glyph_on_close: 0xffffff
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x555555
	dock: false
	dock_bg: 0xaaaaaa
	dock_radius: 0
	dock_padding: 4
	taskbar_bg: 0x0055aa
	taskbar_edge: 0xffffff
	taskbar_text: 0xffffff
	taskbar_text_active: 0xffffff
	taskbar_muted: 0x99c2ee
	taskbar_item_bg: 0x0055aa
	taskbar_item_hover: 0x0066cc
	taskbar_item_active: 0xff8800
	accent: 0xff8800
	accent_dim: 0x995200
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x0055aa
}

// CDE: slate-blue centred titles, a window-menu box at the left, minimise and
//  maximise boxes at the right, thick beveled frames in blue-grey.
const theme_cde = Theme{
	name: 'CDE'
	window_body: 0xaeb2c3
	window_edge: 0x4f5367
	window_radius: 0
	shadow_alpha: 70
	title_height: 24
	title_active_bg: 0x5f7599
	title_active_bg2: 0x5f7599
	title_inactive_bg: 0xaeb2c3
	title_inactive_bg2: 0xaeb2c3
	title_divider: 0x4f5367
	title_text_active: 0xffffff
	title_text_inactive: 0x000000
	title_align: .center
	title_bold: true
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'motif-boxes'
		widgets: [
			WidgetSpec{ action: .menu, anchor: .leading },
			WidgetSpec{ action: .maximize, anchor: .trailing },
			WidgetSpec{ action: .minimize, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xe0e3ed
	bevel_dark: 0x4f5367
	bevel_width: 2
	button_size: 16
	button_gap: 3
	button_inset: 4
	button_hover: 0x7d93b8
	button_close_hover: 0x7d93b8
	button_face: 0xaeb2c3
	button_edge: 0x4f5367
	glyph_color: 0x000000
	glyph_on_close: 0x000000
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x888ea4
	dock: true
	dock_bg: 0xaeb2c3
	dock_radius: 0
	dock_padding: 6
	taskbar_bg: 0xaeb2c3
	taskbar_edge: 0xe0e3ed
	taskbar_text: 0x000000
	taskbar_text_active: 0x000000
	taskbar_muted: 0x5a5e70
	taskbar_item_bg: 0xaeb2c3
	taskbar_item_hover: 0xc4c8d6
	taskbar_item_active: 0x8b93ad
	accent: 0x5f7599
	accent_dim: 0x8b93ad
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x333344
}

// GNOME: a light header bar with a centred title and a single close button, large
//  rounded corners, soft shadows and a dark top bar.
const theme_gnome = Theme{
	name: 'GNOME'
	window_body: 0xfafafa
	window_edge: 0xcdc7c2
	window_radius: 12
	shadow_alpha: 140
	title_height: 36
	title_active_bg: 0xebebeb
	title_active_bg2: 0xe1e1e1
	title_inactive_bg: 0xf6f5f4
	title_inactive_bg2: 0xf6f5f4
	title_divider: 0xc0bfbc
	title_text_active: 0x2e3436
	title_text_inactive: 0x929595
	title_align: .center
	title_bold: true
	title_size: 13
	button_look: .flat
	window_chrome: ChromeSpec{
		widgets: [
			WidgetSpec{ action: .close, anchor: .trailing },
		]
	}
	bevel_enabled: false
	bevel_light: 0
	bevel_dark: 0
	bevel_width: 1
	button_size: 24
	button_gap: 6
	button_inset: 10
	button_hover: 0xd8d6d2
	button_close_hover: 0xd8d6d2
	button_face: 0xe1e1e1
	button_edge: 0xcdc7c2
	glyph_color: 0x2e3436
	glyph_on_close: 0x2e3436
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0xd6d6d6
	dock: false
	dock_bg: 0x1e1e1e
	dock_radius: 10
	dock_padding: 6
	taskbar_bg: 0x1e1e1e
	taskbar_edge: 0x3a3a3a
	taskbar_text: 0xeeeeee
	taskbar_text_active: 0xffffff
	taskbar_muted: 0x9a9996
	taskbar_item_bg: 0x1e1e1e
	taskbar_item_hover: 0x3a3a3a
	taskbar_item_active: 0x3584e4
	accent: 0x3584e4
	accent_dim: 0x1c71d8
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x1e1e1e
}

// Windows 3.1: a navy centred title, a system-menu box at the left and the
//  minimise and maximise arrows at the right, grey beveled boxes on white.
const theme_win31 = Theme{
	name: 'Windows 3.1'
	window_body: 0xffffff
	window_edge: 0x000000
	window_radius: 0
	shadow_alpha: 0
	title_height: 25
	frame_border: 5
	frame_style: .win31
	frame_face: 0xc0c0c0
	frame_light: 0xffffff
	frame_dark: 0x808080
	title_active_bg: 0x000080
	title_active_bg2: 0x000080
	title_inactive_bg: 0xffffff
	title_inactive_bg2: 0xffffff
	title_divider: 0x000000
	title_text_active: 0xffffff
	title_text_inactive: 0x000000
	title_align: .center
	title_bold: true
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'win31-arrows'
		widgets: [
			WidgetSpec{ action: .menu, anchor: .leading },
			WidgetSpec{ action: .maximize, anchor: .trailing },
			WidgetSpec{ action: .minimize, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xffffff
	bevel_dark: 0x808080
	bevel_width: 1
	button_size: 20
	button_gap: 0
	button_inset: 5
	button_hover: 0xdfdfdf
	button_close_hover: 0xdfdfdf
	button_face: 0xc0c0c0
	button_edge: 0x000000
	glyph_color: 0x000000
	glyph_on_close: 0x000000
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x808080
	dock: false
	dock_bg: 0xc0c0c0
	dock_radius: 0
	dock_padding: 4
	taskbar_bg: 0xc0c0c0
	taskbar_edge: 0xffffff
	taskbar_text: 0x000000
	taskbar_text_active: 0xffffff
	taskbar_muted: 0x808080
	taskbar_item_bg: 0xc0c0c0
	taskbar_item_hover: 0xdfdfdf
	taskbar_item_active: 0x000080
	accent: 0x000080
	accent_dim: 0x8080c0
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x008080
}

// Haiku: BeOS's descendant, with a slanted yellow tab as wide as its title needs,
//  a close box and a zoom box inside it, and a light grey window.
const theme_haiku = Theme{
	name: 'Haiku'
	start_menu: .deskbar
	window_body: 0xd8d8d8
	window_edge: 0x7f7f7f
	window_radius: 0
	shadow_alpha: 70
	title_height: 24
	title_active_bg: 0xffd940
	title_active_bg2: 0xffc800
	title_inactive_bg: 0xe4e4e4
	title_inactive_bg2: 0xcfcfcf
	title_divider: 0x7f7f7f
	title_text_active: 0x000000
	title_text_inactive: 0x666666
	title_align: .left
	title_bold: false
	title_size: 12
	button_look: .flat
	window_chrome: ChromeSpec{
		skin: 'beos-boxes'
		kind: .tab
		tab_sizing: .fit
		tab_align: .left
		tab_pad: 10
		tab_slant: 5
		widgets: [
			WidgetSpec{ action: .close, anchor: .leading },
			WidgetSpec{ action: .maximize, anchor: .trailing },
		]
	}
	bevel_enabled: true
	bevel_light: 0xffffff
	bevel_dark: 0x7f7f7f
	bevel_width: 1
	button_size: 16
	button_gap: 4
	button_inset: 6
	button_hover: 0xffe680
	button_close_hover: 0xffe680
	button_face: 0xd8d8d8
	button_edge: 0x7f7f7f
	glyph_color: 0x2a2a2a
	glyph_on_close: 0x2a2a2a
	traffic_close: 0xff5f57
	traffic_minimize: 0xfebc2e
	traffic_zoom: 0x28c840
	traffic_idle: 0x999999
	dock: false
	dock_bg: 0xd8d8d8
	dock_radius: 0
	dock_padding: 6
	taskbar_bg: 0xd8d8d8
	taskbar_edge: 0xffffff
	taskbar_text: 0x000000
	taskbar_text_active: 0x000000
	taskbar_muted: 0x666666
	taskbar_item_bg: 0xd8d8d8
	taskbar_item_hover: 0xe9e9e9
	taskbar_item_active: 0xffd940
	accent: 0xffc800
	accent_dim: 0xb28c00
	shortcut_label: 0xffffff
	shortcut_hover: 0xffffff
	shortcut_panel: 0x333333
}
