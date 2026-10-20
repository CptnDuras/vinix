// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// The cascading Start menus on screen: what their rows hold (the Deskbar menu
// of BeOS, the root menu of Fluxbox), how they are dressed, and how hovering
// and clicking a row opens and runs it. The model they stand on is
// start_cascade.v.
module main

import ui2

// A cascading menu is dressed by a CascadeLook; the two styles differ only in
// these and in which rows their roots hold.
struct CascadeLook {
	frame        u32
	border       u32
	text         u32
	disabled     u32
	hover        u32
	hover_text   u32
	rule         u32
	header       u32
	header_text  u32
	icons        bool
	header_align ui2.Align
	// The colour of the strip down the root box, 0 for none.
	banner       u32
	size         f64
	metrics      CascadeMetrics
}

// BeOS: a pale grey menu in a thin dark outline, small icons beside the names,
// and the Be menu's yellow title above the first row.
const cascade_look_deskbar = CascadeLook{
	frame: 0xd8d8d8
	border: 0x5a5a5a
	text: 0x000000
	disabled: 0x808080
	hover: 0xa9c1e6
	hover_text: 0x000000
	rule: 0x9a9a9a
	header: 0xffcb00
	header_text: 0x000000
	icons: true
	header_align: .left
	size: 12
	metrics: CascadeMetrics{
		row_height: 22
		header_height: 24
		icon_width: 24
		min_width: 168
	}
}

// Fluxbox: a flat dark menu of plain text, its title centred in a bar of the
// highlight colour.
const cascade_look_fluxbox = CascadeLook{
	frame: 0x242a31
	border: 0x0e1115
	text: 0xd8dde4
	disabled: 0x6b7480
	hover: 0x4a6ea9
	hover_text: 0xffffff
	rule: 0x3d4650
	header: 0x4a6ea9
	header_text: 0xffffff
	icons: false
	header_align: .center
	size: 12
	metrics: CascadeMetrics{
		row_height: 22
		header_height: 22
		icon_width: 0
		min_width: 150
	}
}


// KDE 2: a light grey menu with icons, the selection in the title bar's blue
// and Kicker's strip down the left side of the first box.
const cascade_look_kmenu = CascadeLook{
	frame: 0xdcdcdc
	border: 0x4a4a4a
	text: 0x101010
	disabled: 0x808080
	hover: 0x3d63a8
	hover_text: 0xffffff
	rule: 0x9a9a9a
	header: 0xdcdcdc
	header_text: 0x000000
	icons: true
	header_align: .left
	size: 12
	banner: 0x2c4f9e
	metrics: CascadeMetrics{
		row_height: 24
		header_height: 0
		icon_width: 26
		min_width: 176
		banner: 22
	}
}

fn cascade_look(style StartMenuStyle) CascadeLook {
	return match style {
		.deskbar { cascade_look_deskbar }
		.kmenu { cascade_look_kmenu }
		else { cascade_look_fluxbox }
	}
}

// start_menu_style is the Start menu this desktop shows: the user's choice, or
// the look's own.
fn (d &Desktop) start_menu_style() StartMenuStyle {
	return start_menu_style_resolved(d.settings.start_menu, d.theme().start_menu)
}

fn (d &Desktop) start_menu_cascades() bool {
	return d.start_menu_style().cascades()
}

// cascade_programs lists every program, the installed ones first as the
// All Programs view has them.
fn (d &Desktop) cascade_programs(icons bool) []CascadeEntry {
	count := desktop_menu_count()
	mut rows := []CascadeEntry{cap: count}
	for index in 0 .. count {
		if index < available_apps.len {
			factory := &available_apps[index]
			rows << cascade_row(app_title_text(factory.title), app_start_actions[index], if icons {
				factory.icon
			} else {
				''
			})
		} else {
			app := &packaged_apps.apps[index - available_apps.len]
			rows << cascade_row(app.name, app.start_action, if icons { 'builtin:window' } else { '' })
		}
	}
	return rows
}

// cascade_recent lists the programs last used, or the ones a new profile
// starts with.
fn (d &Desktop) cascade_recent(icons bool) []CascadeEntry {
	source := if d.recent_programs.len > 0 { d.recent_programs } else { start_menu_favorites }
	mut rows := []CascadeEntry{cap: source.len}
	for index in source {
		if index < 0 || index >= available_apps.len {
			continue
		}
		factory := &available_apps[index]
		rows << cascade_row(app_title_text(factory.title), app_start_actions[index], if icons {
			factory.icon
		} else {
			''
		})
	}
	return rows
}

// cascade_session is Restart, Sleep where the machine can, and Shut down.
fn (d &Desktop) cascade_session() []CascadeEntry {
	mut rows := [cascade_row(tr('start.restart'), action_start_restart, '')]
	if d.idle.sleep_available {
		rows << cascade_row(tr('start.sleep'), action_start_sleep, '')
	}
	rows << cascade_row(tr('start.shut_down'), action_start_shutdown, '')
	return rows
}

// start_cascade_entries is the root menu of a cascading style.
fn (d &Desktop) start_cascade_entries(style StartMenuStyle) []CascadeEntry {
	icons := cascade_look(style).icons
	files := cascade_row(tr('app.files'), action_start_files, if icons { 'builtin:folder' } else { '' })
	terminal := cascade_row(tr('app.terminal'), action_start_terminal, if icons {
		'builtin:terminal'
	} else {
		''
	})
	settings := cascade_row(tr('app.settings'), action_start_settings, if icons {
		'builtin:settings'
	} else {
		''
	})
	activity := cascade_row(tr('app.activity_monitor'), action_start_activity, if icons {
		'builtin:activity'
	} else {
		''
	})
	system := cascade_row(tr('window.system'), action_start_system, if icons {
		'builtin:window'
	} else {
		''
	})
	programs := cascade_parent(tr('start.programs'), if icons { 'builtin:folder' } else { '' },
		d.cascade_programs(icons))
	recent := cascade_parent(tr('start.recent_programs'), if icons { 'builtin:clock' } else { '' },
		d.cascade_recent(icons))
	mut rows := []CascadeEntry{cap: 16}
	if style == .kmenu {
		// Kicker's K menu: programs first, then the places, the settings, the session.
		rows << programs
		rows << recent
		rows << cascade_separator()
		rows << files
		rows << cascade_row(tr('start.documents'), action_start_documents, 'builtin:documents')
		rows << cascade_parent(tr('start.preferences'), 'builtin:settings', [settings, system])
		rows << terminal
		rows << activity
		rows << cascade_separator()
		rows << cascade_row(tr('start.help'), action_start_welcome, 'builtin:window')
	} else if style == .deskbar {
		// The Be menu: about, then where things are, the preferences, the session.
		rows << cascade_row(tr('start.about'), action_start_welcome, if icons {
			'builtin:vinix'
		} else {
			''
		})
		rows << cascade_separator()
		rows << files
		rows << cascade_row(tr('start.documents'), action_start_documents, if icons {
			'builtin:documents'
		} else {
			''
		})
		rows << recent
		rows << cascade_separator()
		rows << programs
		rows << cascade_parent(tr('start.preferences'), if icons { 'builtin:settings' } else { '' }, [
			settings,
			system,
		])
		rows << terminal
		rows << activity
	} else {
		// Fluxbox's root menu: the usual programs, then the rest under Programs.
		rows << terminal
		rows << files
		rows << cascade_separator()
		rows << programs
		rows << recent
		rows << cascade_separator()
		rows << settings
		rows << activity
		rows << system
		rows << cascade_row(tr('start.help'), action_start_welcome, '')
	}
	rows << cascade_separator()
	rows << d.cascade_session()
	return rows
}

// What the menu was built from, so it is built again only when one of these
// changes: the style, the programs' history, the packages and Sleep.
fn (d &Desktop) start_cascade_key(style StartMenuStyle) u64 {
	mut key := u64(int(style)) + 1
	key = key * 31 + u64(d.recent_programs.len)
	for index in d.recent_programs {
		key = key * 31 + u64(index + 1)
	}
	key = key * 31 + u64(packaged_apps.apps.len)
	key = key * 31 + u64(if d.idle.sleep_available { 1 } else { 0 })
	return key
}

// start_cascade_root is the open menu's rows. They are built when the menu
// opens and again if the style or the history has changed, not on every frame.
fn (mut d Desktop) start_cascade_root() []CascadeEntry {
	style := d.start_menu_style()
	key := d.start_cascade_key(style)
	if d.start_cascade_built != key || d.start_cascade_rows.len == 0 {
		d.start_cascade_rows = d.start_cascade_entries(style)
		d.start_cascade_built = key
	}
	return d.start_cascade_rows
}

// start_cascade_boxes is the place of every open box, above the Start button.
fn (mut d Desktop) start_cascade_boxes() []CascadeRect {
	look := cascade_look(d.start_menu_style())
	return cascade_layout(d.start_cascade_root(), d.start_cascade_path, d.taskbar_padding(),
		d.canvas.height - d.taskbar_height(), d.canvas.width, look.metrics)
}

fn (mut d Desktop) cascade_start_menu_element() ui2.Element {
	look := cascade_look(d.start_menu_style())
	root := d.start_cascade_root()
	boxes := d.start_cascade_boxes()
	shapes := d.start_cascade_shapes()
	frame := cascade_frame(boxes)
	mut children := frame_elements(boxes.len * 2)
	for depth, box in boxes {
		rows := cascade_level(root, d.start_cascade_path, depth)
		children << d.cascade_box(look, rows, depth, box, shapes[depth], frame)
	}
	return ui2.clickable_view(action_start_panel, ui2.rect(f64(frame.x), f64(frame.y), f64(frame.width),
		f64(frame.height)), ui2.BoxStyle{
		transparent: true
	}, children)
}

// cascade_box is one box: its frame, its title if it is the root, its rows.
fn (d &Desktop) cascade_box(look CascadeLook, rows []CascadeEntry, depth int, box CascadeRect, shape CascadeShape, frame CascadeRect) ui2.Element {
	m := look.metrics
	mut children := frame_elements(rows.len * 2 + 7)
	// The strip down the root box, and the rows to its right.
	if shape.banner > 0 && look.banner != 0 {
		children << ui2.view('start.cas.banner', ui2.rect(1, 1, f64(shape.banner), f64(box.height - 2)), ui2.BoxStyle{
			bg: look.banner
		}, [])
	}
	if shape.header > 0 {
		mut title_children := frame_elements(1)
		if look.icons {
			title_children << ui2.button_with_image('', '', 'builtin:vinix', ui2.rect(4, 3, f64(shape.header - 6),
				f64(shape.header - 6)), ui2.BoxStyle{
				transparent: true
			}, ui2.TextStyle{
				color: look.header_text
			})
		}
		children << ui2.view('start.cas.title', ui2.rect(1, 1, f64(box.width - 2), f64(shape.header - 1)), ui2.BoxStyle{
			bg: look.header
		}, title_children)
		indent := if look.icons { f64(shape.header) } else { f64(0) }
		children << ui2.label('start.cas.title.text', 'Vinix', ui2.rect(indent, 3, f64(box.width) - indent,
			f64(shape.header - 6)), ui2.TextStyle{
			color: look.header_text
			size: look.size
			bold: true
			align: look.header_align
		})
	}
	for index, row in rows {
		top := cascade_row_y(rows, shape, index, m)
		left := cascade_row_x(shape, index)
		if row.separator {
			children << ui2.view('start.cas.rule.${depth}.${index}', ui2.rect(f64(left + 4), f64(top + m.separator_height / 2),
				f64(shape.column_width - 8), 1), ui2.BoxStyle{
				bg: look.rule
			}, [])
			continue
		}
		id := cascade_row_id(depth, index)
		open := depth < d.start_cascade_path.len && d.start_cascade_path[depth] == index
		lit := row.enabled && (d.hover == id || open)
		text_color := if !row.enabled {
			look.disabled
		} else if lit {
			look.hover_text
		} else {
			look.text
		}
		area := ui2.rect(f64(left + 2), f64(top), f64(shape.column_width - 4), f64(m.row_height))
		box_style := ui2.BoxStyle{
			bg: if lit { look.hover } else { look.frame }
			transparent: !lit
		}
		style := ui2.TextStyle{
			color: text_color
			size: look.size
			align: .left
		}
		if row.icon.len > 0 && look.icons {
			children << ui2.button_with_image(id, row.title, row.icon, area, box_style, style)
		} else {
			children << ui2.button(id, row.title, area, box_style, style)
		}
		if row.children.len > 0 {
			children << ui2.button_with_image(id, '', 'builtin:arrow_right', ui2.rect(f64(left + shape.column_width - 22),
				f64(top + 2), 18, f64(m.row_height - 4)), ui2.BoxStyle{
				transparent: true
			}, ui2.TextStyle{
				color: text_color
			})
		}
	}
	// The desktop's own renderer draws no outline for a box, so the outline is
	// four hairlines over its edges.
	w := f64(box.width)
	h := f64(box.height)
	edge := ui2.BoxStyle{
		bg: look.border
	}
	children << ui2.view('start.cas.edge.top', ui2.rect(0, 0, w, 1), edge, [])
	children << ui2.view('start.cas.edge.bottom', ui2.rect(0, h - 1, w, 1), edge, [])
	children << ui2.view('start.cas.edge.left', ui2.rect(0, 0, 1, h), edge, [])
	children << ui2.view('start.cas.edge.right', ui2.rect(w - 1, 0, 1, h), edge, [])
	return ui2.view('start.cas.box.${depth}', ui2.rect(f64(box.x - frame.x), f64(box.y - frame.y), w, h), ui2.BoxStyle{
		bg: look.frame
	}, children)
}

// start_cascade_reset closes every submenu.
fn (mut d Desktop) start_cascade_reset() {
	if d.start_cascade_path.len > 0 {
		d.start_cascade_path = []int{}
	}
}

// update_start_cascade_hover opens and closes submenus as the pointer rests on
// rows, which is how both menus behave.
fn (mut d Desktop) update_start_cascade_hover() {
	depth, index := cascade_row_parse(d.hover) or { return }
	root := d.start_cascade_root()
	next := cascade_hover(root, d.start_cascade_path, depth, index)
	if next != d.start_cascade_path {
		d.start_cascade_path = next
		d.dirty = true
	}
}

// cascade_action runs a click on a row: a parent opens, anything else is
// the action it carries.
fn (mut d Desktop) cascade_action(id string) {
	depth, index := cascade_row_parse(id) or { return }
	root := d.start_cascade_root()
	row := cascade_find(root, d.start_cascade_path, depth, index) or { return }
	if !row.enabled || row.separator {
		return
	}
	if row.children.len > 0 {
		d.start_cascade_path = cascade_hover(root, d.start_cascade_path, depth, index)
		d.dirty = true
		return
	}
	if row.action.len > 0 {
		d.handle_start_action(row.action)
	}
}

// start_cascade_shapes is how each open box divides its rows into columns.
fn (mut d Desktop) start_cascade_shapes() []CascadeShape {
	look := cascade_look(d.start_menu_style())
	return cascade_shapes(d.start_cascade_root(), d.start_cascade_path, d.canvas.height - d.taskbar_height(),
		look.metrics)
}
