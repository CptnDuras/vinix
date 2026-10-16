// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Skins compiled into the desktop: their skin.cfg and their vector art as
// text, so a look can have its own controls without any installed files.
module main

const builtin_skin_ids = ['beos-boxes']

fn builtin_skin_name(id string) string {
	return match id {
		'beos-boxes' { 'BeOS boxes' }
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
		else {
			none
		}
	}
}

fn builtin_skin_asset(id string, file string) ?string {
	if id != 'beos-boxes' {
		return none
	}
	return match file {
		// Outer square, then the same square inset and wound the other way: the
		// non-zero fill leaves a 1.5 unit frame.
		'close.vec' {
			'viewbox 12 12\npath M0 0 H12 V12 H0 Z M1.5 1.5 V10.5 H10.5 V1.5 Z\n'
		}
		'zoom.vec' {
			'viewbox 12 12\npath M4 0 H12 V8 H4 Z M5.5 1.5 V6.5 H10.5 V1.5 Z\npath M0 4 H8 V12 H0 Z M1.5 5.5 V10.5 H6.5 V5.5 Z\n'
		}
		else {
			none
		}
	}
}
