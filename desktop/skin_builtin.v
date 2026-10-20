// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Skins compiled into the desktop: their skin.cfg and their vector art as
// text, so a look can have its own controls without any installed files. Every
// vector is drawn in the look's glyph colour. The boxes are a 12 by 12 square;
// a hole is a second contour wound the other way, which the non-zero fill
// leaves empty.
module main

const builtin_skin_ids = ['beos-boxes', 'next-gadgets', 'amiga-gadgets', 'motif-boxes', 'win31-arrows', 'kde2-buttons']

fn builtin_skin_name(id string) string {
	return match id {
		'beos-boxes' { 'BeOS boxes' }
		'next-gadgets' { 'NeXTSTEP' }
		'amiga-gadgets' { 'Amiga gadgets' }
		'motif-boxes' { 'Motif boxes' }
		'win31-arrows' { 'Windows 3.1' }
		'kde2-buttons' { 'KDE 2 buttons' }
		else { id }
	}
}

fn builtin_skin_cfg(id string) ?string {
	return match id {
		'beos-boxes' {
			// The close box and the zoom box of the Be tab: hollow squares, the
			// zoom box being two of them overlapping.
			'name=BeOS boxes\nwidget.close=vector:close.vec\nwidget.maximize=vector:zoom.vec\nwidget.close.size=14\nwidget.maximize.size=14\n'
		}
		'next-gadgets' {
			// A cross to close, and the miniaturise box: a window with a thick top.
			'name=NeXTSTEP\nwidget.close=vector:close.vec\nwidget.minimize=vector:mini.vec\nwidget.close.size=12\nwidget.minimize.size=12\n'
		}
		'amiga-gadgets' {
			// The close gadget, the zoom gadget and the depth gadget.
			'name=Amiga gadgets\nwidget.close=vector:close.vec\nwidget.maximize=vector:zoom.vec\nwidget.shade=vector:depth.vec\nwidget.close.size=12\nwidget.maximize.size=12\nwidget.shade.size=12\n'
		}
		'motif-boxes' {
			// The window menu box, the minimise dot and the maximise square.
			'name=Motif boxes\nwidget.menu=vector:menu.vec\nwidget.minimize=vector:mini.vec\nwidget.maximize=vector:maxi.vec\nwidget.menu.size=14\nwidget.minimize.size=14\nwidget.maximize.size=14\n'
		}
		'kde2-buttons' {
			// The raised square buttons of KDE 2's titles, each with its mark.
			'name=KDE 2 buttons\nwidget.menu=vector:menu.vec\nwidget.minimize=vector:mini.vec\nwidget.maximize=vector:maxi.vec\nwidget.close=vector:close.vec\nwidget.shade=vector:shade.vec\nwidget.menu.size=16\nwidget.minimize.size=16\nwidget.maximize.size=16\nwidget.close.size=16\nwidget.shade.size=16\n'
		}
		'win31-arrows' {
			// The system-menu dash and the two arrows.
			'name=Windows 3.1\nwidget.menu=vector:menu.vec\nwidget.minimize=vector:down.vec\nwidget.maximize=vector:up.vec\nwidget.menu.size=14\nwidget.minimize.size=14\nwidget.maximize.size=14\n'
		}
		else {
			none
		}
	}
}

fn builtin_skin_asset(id string, file string) ?string {
	return match id {
		'beos-boxes' {
			match file {
				// Outer square, then the same square inset and wound the other way:
				// the non-zero fill leaves a 1.5 unit frame.
				'close.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 1.5 V10.5 H10.5 V1.5 Z\n' }
				'zoom.vec' { 'viewbox 12 12\npath M4 0 H12 V8 H4 Z M5.5 1.5 V6.5 H10.5 V1.5 Z\npath M0 4 H8 V12 H0 Z M1.5 5.5 V10.5 H6.5 V5.5 Z\n' }
				else { none }
			}
		}
		'next-gadgets' {
			match file {
				'close.vec' { 'viewbox 12 12\npath M1.5 0 L6 4.5 L10.5 0 L12 1.5 L7.5 6 L12 10.5 L10.5 12 L6 7.5 L1.5 12 L0 10.5 L4.5 6 L0 1.5 Z\n' }
				'mini.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 3.5 V10.5 H10.5 V3.5 Z\n' }
				else { none }
			}
		}
		'amiga-gadgets' {
			match file {
				'close.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 1.5 V10.5 H10.5 V1.5 Z\npath M4 4 H8 V8 H4 Z\n' }
				'zoom.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 1.5 V10.5 H10.5 V1.5 Z\npath M1.5 1.5 H6 V6 H1.5 Z\n' }
				'depth.vec' { 'viewbox 12 12\npath M0 0 H8 V8 H0 Z M1.5 1.5 V6.5 H6.5 V1.5 Z\npath M4 4 H12 V12 H4 Z\n' }
				else { none }
			}
		}
		'motif-boxes' {
			match file {
				'menu.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 1.5 V10.5 H10.5 V1.5 Z\npath M3 5 H9 V7 H3 Z\n' }
				'mini.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 1.5 V10.5 H10.5 V1.5 Z\npath M4 4 H8 V8 H4 Z\n' }
				'maxi.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M3 3 V9 H9 V3 Z\n' }
				else { none }
			}
		}
		'kde2-buttons' {
			match file {
				// Each is the button's outline, then its mark, wound the same way as
				// the outline so the non-zero fill keeps both and leaves the face open.
				'menu.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.2 1.2 V10.8 H10.8 V1.2 Z\npath M3 3.5 H9 V4.7 H3 Z M3 5.4 H9 V6.6 H3 Z M3 7.3 H9 V8.5 H3 Z\n' }
				'mini.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.2 1.2 V10.8 H10.8 V1.2 Z\npath M3 7.5 H9 V9 H3 Z\n' }
				'maxi.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.2 1.2 V10.8 H10.8 V1.2 Z\npath M3 3 H9 V9 H3 Z M4.2 4.5 V7.8 H7.8 V4.5 Z\n' }
				'close.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.2 1.2 V10.8 H10.8 V1.2 Z\npath M3.75 3 L6 5.25 L8.25 3 L9 3.75 L6.75 6 L9 8.25 L8.25 9 L6 6.75 L3.75 9 L3 8.25 L5.25 6 L3 3.75 Z\n' }
				'shade.vec' { 'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.2 1.2 V10.8 H10.8 V1.2 Z\npath M3 3 H9 V4.5 H3 Z\n' }
				else { none }
			}
		}
		'win31-arrows' {
			match file {
				'menu.vec' { 'viewbox 12 12\npath M1 5 H11 V7 H1 Z\n' }
				'down.vec' { 'viewbox 12 12\npath M1 3 H11 L6 9 Z\n' }
				'up.vec' { 'viewbox 12 12\npath M6 3 L11 9 H1 Z\n' }
				else { none }
			}
		}
		else {
			none
		}
	}
}
