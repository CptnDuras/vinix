// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue reference era presets (spec G2): Windows 2000, Mac OS Platinum, BeOS.
// Each is a Theme built with the shared bevel vocabulary and a restrained
// palette, demonstrating that the reference environments are configuration.
// Registered in lookandfeel.v; the shell/behavior character is set there.
module main

// Windows 2000: warm-neutral 0xc0c0c0 gray, hard raised/sunken bevels, a blue
// gradient active title, square corners, right-side buttons.
const theme_win2k = Theme{
	name:                'Windows 2000'
	window_body:         0xc0c0c0
	window_edge:         0x808080
	window_radius:       0
	shadow_alpha:        60
	title_height:        24
	title_active_bg:     0x0a246a
	title_active_bg2:    0xa6caf0
	title_inactive_bg:   0x808080
	title_inactive_bg2:  0xc0c0c0
	title_divider:       0x808080
	title_text_active:   0xffffff
	title_text_inactive: 0xd4d0c8
	title_align:         .left
	title_bold:          true
	title_size:          12
	button_look:         .flat
	bevel_enabled:       true
	bevel_light:         0xffffff
	bevel_dark:          0x404040
	bevel_width:         1
	button_size:         18
	button_gap:          2
	button_inset:        4
	button_hover:        0xd4d0c8
	button_close_hover:  0xd4d0c8
	button_face:         0xc0c0c0
	button_edge:         0x808080
	glyph_color:         0x000000
	glyph_on_close:      0x000000
	traffic_close:       0xff5f57
	traffic_minimize:    0xfebc2e
	traffic_zoom:        0x28c840
	traffic_idle:        0x808080
	dock:                false
	dock_bg:             0xc0c0c0
	dock_radius:         0
	dock_padding:        6
	taskbar_bg:          0xc0c0c0
	taskbar_edge:        0xffffff
	taskbar_text:        0x000000
	taskbar_text_active: 0x000000
	taskbar_muted:       0x808080
	taskbar_item_bg:     0xc0c0c0
	taskbar_item_hover:  0xd4d0c8
	taskbar_item_active: 0xa0a0a0
	accent:              0x0a246a
	accent_dim:          0x7f9db9
	shortcut_label:      0xffffff
	shortcut_hover:      0xffffff
	shortcut_panel:      0x000000
}

// Mac OS Platinum: cool gray, a pinstriped/quiet title bar, grooved dividers,
// centered title, square-ish corners, and a top menu bar (set in the preset).
const theme_platinum = Theme{
	name:                'Platinum'
	window_body:         0xdddddd
	window_edge:         0x888888
	window_radius:       2
	shadow_alpha:        70
	title_height:        22
	title_active_bg:     0xcccccc
	title_active_bg2:    0xbbbbbb
	title_inactive_bg:   0xdddddd
	title_inactive_bg2:  0xd4d4d4
	title_divider:       0x999999
	title_text_active:   0x1a1a1a
	title_text_inactive: 0x888888
	title_align:         .center
	title_bold:          true
	title_size:          12
	button_look:         .flat
	chrome: ChromeSpec{
		// A close box at one end; the zoom and collapse boxes at the other.
		widgets: [
			WidgetSpec{ action: .close, anchor: .leading },
			WidgetSpec{ action: .maximize, anchor: .trailing },
			WidgetSpec{ action: .shade, anchor: .trailing },
		]
	}
	bevel_enabled:       true
	bevel_light:         0xf4f4f4
	bevel_dark:          0x999999
	bevel_width:         1
	button_size:         18
	button_gap:          4
	button_inset:        6
	button_hover:        0xcccccc
	button_close_hover:  0xcccccc
	button_face:         0xdddddd
	button_edge:         0x888888
	glyph_color:         0x333333
	glyph_on_close:      0x333333
	traffic_close:       0xff5f57
	traffic_minimize:    0xfebc2e
	traffic_zoom:        0x28c840
	traffic_idle:        0x999999
	dock:                false
	dock_bg:             0xdddddd
	dock_radius:         4
	dock_padding:        6
	taskbar_bg:          0xcccccc
	taskbar_edge:        0xf4f4f4
	taskbar_text:        0x1a1a1a
	taskbar_text_active: 0x000000
	taskbar_muted:       0x888888
	taskbar_item_bg:     0xcccccc
	taskbar_item_hover:  0xbbbbbb
	taskbar_item_active: 0xaaaaaa
	accent:              0x3355aa
	accent_dim:          0x99aad4
	shortcut_label:      0xffffff
	shortcut_hover:      0xffffff
	shortcut_panel:      0x333333
}

// BeOS: restraint and tight spacing, a slightly greenish light gray, a yellow
// title accent, square corners, and a title that is a tab rather than a bar.
const theme_beos = Theme{
	name:                'BeOS'
	window_body:         0xdedede
	window_edge:         0x9a9a9a
	window_radius:       0
	shadow_alpha:        60
	title_height:        22
	title_active_bg:     0xffce00
	title_active_bg2:    0xf0c000
	title_inactive_bg:   0xcfcfcf
	title_inactive_bg2:  0xc4c4c4
	title_divider:       0x9a9a9a
	title_text_active:   0x1a1a1a
	title_text_inactive: 0x777777
	title_align:         .left
	title_bold:          true
	title_size:          12
	button_look:         .flat
	chrome: ChromeSpec{
		// The yellow tab is a tag on the window's top edge, not a bar across it:
		// as wide as its title needs, at the left, with a close box and a zoom
		// box inside it.
		kind: .tab
		tab_sizing: .fit
		tab_align: .left
		tab_pad: 8
		tab_overlap: 0
		widgets: [
			WidgetSpec{ action: .close, anchor: .leading },
			WidgetSpec{ action: .maximize, anchor: .trailing },
		]
	}
	bevel_enabled:       true
	bevel_light:         0xf6f6f6
	bevel_dark:          0x8a8a8a
	bevel_width:         1
	button_size:         16
	button_gap:          3
	button_inset:        5
	button_hover:        0xe4e4e4
	button_close_hover:  0xe4e4e4
	button_face:         0xdedede
	button_edge:         0x9a9a9a
	glyph_color:         0x333333
	glyph_on_close:      0x333333
	traffic_close:       0xff5f57
	traffic_minimize:    0xfebc2e
	traffic_zoom:        0x28c840
	traffic_idle:        0x9a9a9a
	dock:                false
	dock_bg:             0xdedede
	dock_radius:         0
	dock_padding:        6
	taskbar_bg:          0xcfcfcf
	taskbar_edge:        0xf6f6f6
	taskbar_text:        0x1a1a1a
	taskbar_text_active: 0x000000
	taskbar_muted:       0x777777
	taskbar_item_bg:     0xcfcfcf
	taskbar_item_hover:  0xe4e4e4
	taskbar_item_active: 0xffce00
	accent:              0xffce00
	accent_dim:          0xd8b000
	shortcut_label:      0xffffff
	shortcut_hover:      0xffffff
	shortcut_panel:      0x333333
}
