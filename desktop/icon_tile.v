// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Decorations — the shared icon-tile renderer (spec B, ISSUES.md ISSUE-3).
//
// An icon tile is the app-glyph + label + hover/press visual used both by the
// wallpaper desktop shortcuts (H2/H3) and by the shell launcher item (E4). It
// is a single visual primitive owned by Decorations (B); the two callers are
// *hosts* that place tiles — they share this renderer but keep independent
// placement and pinned-set models. Keeping one renderer means the two hosts can
// never drift apart visually.
module main

import ui2

// IconTileStyle carries the resolved colours a tile draws with. The caller
// resolves them from the active Theme/Decor so the tile itself holds no
// literals and both hosts style identically.
struct IconTileStyle {
	label u32 // glyph + label colour at rest
	hover u32 // glyph + label colour while hovered
	panel u32 // tile background (shown while hovered; transparent otherwise)
	// The title is a copy the frame owns and free_tree releases, for a title
	// that does not outlive the frame (a directory entry's name).
	own_title bool
}

// icon_tile builds one app tile: a centred glyph above a centred label, inside
// a clickable_view carrying `action`. The tile paints its panel background only
// while hovered, matching today's wallpaper shortcut look. `label_shadow` adds
// a text shadow (wallpaper shortcuts sit over the wallpaper and need it; a
// launcher inside an opaque panel does not).
//
// `compact` renders an icon-only tile that fills the given rect (the launcher
// strip in a thin panel uses this); the full tile is glyph-over-label sized for
// the wallpaper. Either way it is the same renderer, so the two hosts (E4
// launcher, H2/H3 desktop shortcuts) never drift apart (ISSUES.md ISSUE-3).
fn icon_tile(action string, icon string, title string, rect ui2.Rect, hovered bool, style IconTileStyle, label_shadow bool) ui2.Element {
	return icon_tile_ex(action, icon, title, rect, hovered, style, label_shadow, false)
}

fn icon_tile_ex(action string, icon string, title string, rect ui2.Rect, hovered bool, style IconTileStyle, label_shadow bool, compact bool) ui2.Element {
	color := if hovered { style.hover } else { style.label }
	if compact {
		// Icon-only tile filling the rect: a centred glyph, no label. Used by
		// the launcher strip in a thin panel.
		inset := f64(3)
		mut kids := frame_elements(1)
		kids << ui2.button_with_image('', '', icon, ui2.rect(inset, inset, rect.width - 2 * inset, rect.height - 2 * inset), ui2.BoxStyle{
			transparent: true
		}, ui2.TextStyle{
			color: color
		})
		return ui2.clickable_view(action, rect, ui2.BoxStyle{
			bg: style.panel
			radius: 4
			transparent: !hovered
		}, kids)
	}
	icon_x := (int(rect.width) - shortcut_icon) / 2
	mut children := frame_elements(2)
	children << ui2.button_with_image('', '', icon, ui2.rect(f64(icon_x), 10, f64(shortcut_icon), f64(shortcut_icon)), ui2.BoxStyle{
		transparent: true
	}, ui2.TextStyle{
		color: color
	})
	children << ui2.label(if style.own_title { frame_owned_text_id } else { '' }, title, ui2.rect(0, f64(shortcut_icon + 16), rect.width, 18), ui2.TextStyle{
		color: color
		shadow: label_shadow
		size: 12
		align: .center
	})
	return ui2.clickable_view(action, rect, ui2.BoxStyle{
		bg: style.panel
		radius: 8
		transparent: !hovered
	}, children)
}
