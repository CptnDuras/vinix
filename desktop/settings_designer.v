// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Settings > Appearance: the look, the shape of a window's title bar, the
// controls on it and what clicking it does, in one page. Its top is a
// miniature window wearing the look in force; the user rearranges its title bar
// by dragging (appearance_designer.v has the rules), and every other control on
// the page changes the same picture.
module main

import ui2

const settings_action_atab = 'settings.atab.'
const settings_action_tabwidth = 'settings.tabwidth.'
const settings_action_title_dbl = 'settings.titleact.dbl.'
const settings_action_title_mid = 'settings.titleact.mid.'
const settings_action_startmenu = 'settings.startmenu.'

// The page's sections, in tab order.
const appearance_tab_look = 0
const appearance_tab_title = 1
const appearance_tab_controls = 2
const appearance_tab_actions = 3
const appearance_tab_skin = 4
const appearance_tab_start = 5
const appearance_tab_count = 6

// How far a pointer must travel between press and release for the press to have
// been a drag rather than a click.
const designer_drag_slop = 4

// The tab widths a choice offers: follow the look, fit the content, then shares
// of the window.
const settings_tab_width_choices = [-1, 0, 25, 50, 75, 100]

// What a title-bar click can do, as choices: follow the look, then each action.
const settings_title_actions = [TitleAction.maximize, .shade, .hide, .none_]

// DzDrag is a press on the designer that has not been released.
struct DzDrag {
mut:
	kind    DzHitKind = .nothing
	action  WidgetAction
	x       int // the pointer now, in the pane's coordinates
	y       int
	start_x int
	start_y int
	// For a tab: how far from its left edge it was picked up.
	grab int
}

fn (d DzDrag) active() bool {
	return d.kind != .nothing
}

fn (d DzDrag) moved() bool {
	return absi(d.x - d.start_x) >= designer_drag_slop || absi(d.y - d.start_y) >= designer_drag_slop
}

// designer_metrics_for takes the miniature's measurements from the look, bounded
// so an odd look cannot make the page unusable.
fn designer_metrics_for(theme Theme) DzMetrics {
	return DzMetrics{
		bar_h: clamp_int(theme.title_height, 20, 34)
		widget_size: clamp_int(if theme.button_size > 0 { theme.button_size } else { 16 }, 12, 22)
		widget_gap: clamp_int(theme.button_gap, 2, 8)
		widget_inset: clamp_int(theme.button_inset, 3, 12)
	}
}

fn (a &SettingsApp) designer_frame_width(pane_width int) int {
	return clamp_int(pane_width - 2 * settings_padding, 120, 480)
}

// designer_layout_in is the miniature's layout for a pane pane_width across.
fn (a &SettingsApp) designer_layout_in(pane_width int) DzLayout {
	spec := a.windows_pane_state()
	return designer_layout(spec, settings_padding, settings_padding, a.designer_frame_width(pane_width),
		designer_metrics_for(a.desktop.theme()))
}

// designer_bottom is the first row under the miniature and its tray.
fn (a &SettingsApp) designer_bottom(l DzLayout) int {
	return l.tray.y + l.tray.h
}

fn designer_glyph(action WidgetAction, x int, y int, size int, color u32) []ui2.Element {
	// The controls' faces are drawn from rectangles, so they need no font.
	mut out := []ui2.Element{cap: 4}
	unit := if size >= 16 { 2 } else { 1 }
	box := ui2.BoxStyle{
		bg: color
	}
	match action {
		.close {
			// Diagonals cannot be drawn from rectangles, so the cross is a letter.
			out << ui2.label('', 'x', ui2.rect(f64(x), f64(y), f64(size), f64(size)), ui2.TextStyle{
				color: color
				size: 13
				bold: true
				align: .center
				vertical_align: 'middle'
			})
		}
		.minimize {
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + size - 5 - unit), f64(size - 6), f64(2 * unit)), box, [])
		}
		.maximize {
			// A hollow square from four bars; a transparent box draws no border.
			side := size - 6
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + 3), f64(side), f64(unit)), box, [])
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + 3 + side - unit), f64(side), f64(unit)), box, [])
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + 3), f64(unit), f64(side)), box, [])
			out << ui2.view('', ui2.rect(f64(x + 3 + side - unit), f64(y + 3), f64(unit), f64(side)), box, [])
		}
		.shade {
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + size / 2 - 3), f64(size - 6), f64(unit)), box, [])
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + size / 2 + 1), f64(size - 6), f64(unit)), box, [])
		}
		.menu {
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + size / 2 - 4), f64(size - 6), f64(unit)), box, [])
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + size / 2 - 1), f64(size - 6), f64(unit)), box, [])
			out << ui2.view('', ui2.rect(f64(x + 3), f64(y + size / 2 + 2), f64(size - 6), f64(unit)), box, [])
		}
	}
	return out
}

// designer_control draws one control the way the look draws its buttons: a
// coloured disc for a traffic-light look, a small bevelled button where the look
// has bevels, and a bare glyph on the bar for the flat looks.
fn designer_control(theme Theme, action WidgetAction, x int, y int, size int, ghost bool) ui2.Element {
	traffic := theme.button_look == .traffic
	mut glyph := theme.glyph_color
	mut box := ui2.BoxStyle{
		transparent: true
	}
	if traffic {
		face := match action {
			.close { theme.traffic_close }
			.minimize { theme.traffic_minimize }
			.maximize { theme.traffic_zoom }
			else { theme.traffic_idle }
		}
		glyph = 0x333333
		box = ui2.BoxStyle{
			bg: face
			radius: f64(size) / 2
		}
	} else if theme.bevel_enabled {
		box = ui2.BoxStyle{
			bg: theme.button_face
			radius: 2
			border_color: theme.button_edge
			border_left: 1
			border_top: 1
			border_right: 1
			border_bottom: 1
		}
	} else if ghost {
		// A control being carried needs a face to be seen against the page.
		box = ui2.BoxStyle{
			bg: theme.title_active_bg
			radius: 2
		}
	}
	mut kids := []ui2.Element{}
	if !traffic || ghost {
		kids << designer_glyph(action, 0, 0, size, glyph)
	}
	return ui2.view('', ui2.rect(f64(x), f64(y), f64(size), f64(size)), box, kids)
}

// designer_elements is the miniature, its tray and the drag in progress.
fn (a &SettingsApp) designer_elements(pane_width int) []ui2.Element {
	theme := a.desktop.theme()
	l := a.designer_layout_in(pane_width)
	m := l.metrics
	mut out := []ui2.Element{cap: 40}

	// The window: a body under a title bar, or under a tab.
	out << ui2.view('', ui2.rect(f64(l.body.x), f64(l.body.y), f64(l.body.w), f64(l.body.h)), ui2.BoxStyle{
		bg: theme.window_body
		border_color: theme.window_edge
		border_left: 1
		border_right: 1
		border_bottom: 1
		border_top: if l.is_tab { f64(1) } else { f64(0) }
		radius: if theme.window_radius > 6 { f64(6) } else { f64(theme.window_radius) }
	}, [])
	out << ui2.label('', tr('settings.designer.window'), ui2.rect(f64(l.body.x + 12), f64(l.body.y + l.body.h / 2 - 8),
		f64(l.body.w - 24), 16), ui2.TextStyle{
		color: body_muted
		size: 11
	})
	out << ui2.view('', ui2.rect(f64(l.bar.x), f64(l.bar.y), f64(l.bar.w), f64(l.bar.h)), ui2.BoxStyle{
		bg: theme.title_active_bg
		border_color: theme.window_edge
		border_left: if l.is_tab { f64(1) } else { f64(0) }
		border_right: if l.is_tab { f64(1) } else { f64(0) }
		border_top: if l.is_tab { f64(1) } else { f64(0) }
		radius: if l.is_tab && theme.window_radius > 0 { f64(3) } else { f64(0) }
	}, [])
	// The title sits between the two runs of controls.
	lead_end := l.bar.x + m.widget_inset + widget_extent(l.spec.widgets, .leading, m.widget_size, m.widget_gap) + m.widget_gap
	trail_start := l.bar.x + l.bar.w - m.widget_inset - widget_extent(l.spec.widgets, .trailing, m.widget_size, m.widget_gap) - m.widget_gap
	if trail_start - lead_end > 20 {
		out << ui2.label('', tr('settings.designer.title'), ui2.rect(f64(lead_end), f64(l.bar.y + (l.bar.h - 16) / 2),
			f64(trail_start - lead_end), 16), ui2.TextStyle{
			color: theme.title_text_active
			size: 11
			bold: theme.title_bold
			align: match theme.title_align {
				.left { ui2.Align.left }
				.center { ui2.Align.center }
				.right { ui2.Align.right }
			}
		})
	}
	dragging := a.dz_drag.kind == .widget || a.dz_drag.kind == .chip
	for p in l.placed {
		if dragging && p.action == a.dz_drag.action {
			// The control being carried leaves a gap behind it.
			continue
		}
		out << designer_control(theme, p.action, p.rect.x, p.rect.y, p.rect.w, false)
	}
	if l.is_tab {
		// The grip: a short bar on the tab's edge.
		out << ui2.view('', ui2.rect(f64(l.handle.x + 3), f64(l.handle.y + 4), 2, f64(l.handle.h - 8)), ui2.BoxStyle{
			bg: if a.dz_drag.kind == .handle { app_accent } else { theme.window_edge }
			radius: 1
		}, [])
	}

	// The tray: every control, lit when it is off the bar and so can be added.
	removing := dragging && a.designer_drop_now(l).kind == .remove
	for chip in l.chips {
		lit := !chip.on_bar || (dragging && chip.action == a.dz_drag.action)
		out << ui2.view('', ui2.rect(f64(chip.rect.x), f64(chip.rect.y), f64(chip.rect.w), f64(chip.rect.h)), ui2.BoxStyle{
			bg: if removing && chip.action == a.dz_drag.action {
				u32(0xf3c9c4)
			} else if lit {
				settings_choice_bg
			} else {
				app_surface
			}
			radius: 5
			border_color: body_rule
			border_left: 1
			border_top: 1
			border_right: 1
			border_bottom: 1
		}, [
			ui2.label('', widget_action_title(chip.action), ui2.rect(0, 0, f64(chip.rect.w), f64(chip.rect.h)), ui2.TextStyle{
				color: if lit { body_text } else { body_muted }
				size: 11
				align: .center
				vertical_align: 'middle'
			}),
		])
	}

	// The drag in progress: where a dropped control would land, and the control
	// itself following the pointer.
	if a.dz_drag.active() && dragging {
		drop := a.designer_drop_now(l)
		x := designer_insertion_x(l, a.dz_drag.action, drop)
		if x >= 0 {
			out << ui2.view('', ui2.rect(f64(x - 1), f64(l.bar.y + 2), 3, f64(l.bar.h - 4)), ui2.BoxStyle{
				bg: app_accent
				radius: 1
			}, [])
		}
		out << designer_control(theme, a.dz_drag.action, a.dz_drag.x - m.widget_size / 2,
			a.dz_drag.y - m.widget_size / 2, m.widget_size, true)
	}
	return out
}

fn (a &SettingsApp) designer_drop_now(l DzLayout) DzDrop {
	return designer_drop(l, a.dz_drag.action, a.dz_drag.x, a.dz_drag.y)
}

// pointer_input_enabled and the two methods below make Settings a pointer
// application in the narrow way pointer_drag_only describes: the desktop hands
// it a left press and the drag that follows, and the controls on the page keep
// working by action id as before.
fn (a &SettingsApp) pointer_input_enabled() bool {
	return true
}

fn (a &SettingsApp) pointer_moves_matter() bool {
	return a.dz_drag.active()
}

fn (mut a SettingsApp) pointer_event(phase AppPointerPhase, button AppPointerButton, scroll int, x int, y int, width int, height int) {
	if a.desktop == unsafe { nil } || a.category != .appearance || a.searching() {
		a.dz_drag = DzDrag{}
		return
	}
	pane_width := width - (settings_sidebar_width + 1)
	px := x - (settings_sidebar_width + 1)
	py := y
	match phase {
		.down {
			if button != .left {
				return
			}
			l := a.designer_layout_in(pane_width)
			hit := designer_hit(l, px, py)
			if hit.kind in [.widget, .chip, .handle, .tab] {
				a.dz_drag = DzDrag{
					kind: hit.kind
					action: hit.action
					x: px
					y: py
					start_x: px
					start_y: py
					grab: px - l.bar.x
				}
			}
		}
		.move {
			if !a.dz_drag.active() {
				return
			}
			a.dz_drag.x = px
			a.dz_drag.y = py
			a.designer_drag_live(pane_width)
		}
		.up {
			if !a.dz_drag.active() {
				return
			}
			a.dz_drag.x = px
			a.dz_drag.y = py
			a.designer_finish(pane_width)
			a.dz_drag = DzDrag{}
		}
		else {}
	}
}

// designer_drag_live applies what a tab or its grip is doing as it happens, so
// the miniature resizes and slides under the pointer.
fn (mut a SettingsApp) designer_drag_live(pane_width int) {
	l := a.designer_layout_in(pane_width)
	match a.dz_drag.kind {
		.handle {
			a.desktop.settings.ov_tab_width = designer_tab_percent(l, a.dz_drag.x)
		}
		.tab {
			// The tab's middle follows the pointer; it settles at the nearest of
			// the three places a tab can sit.
			middle := a.dz_drag.x - a.dz_drag.grab + l.bar.w / 2
			a.desktop.settings.ov_tab_align = designer_tab_align(l, middle)
		}
		else {}
	}
}

// designer_finish does what releasing the pointer means: a dropped control
// goes where it was dropped, and a press on a tray chip that went nowhere
// toggles that control.
fn (mut a SettingsApp) designer_finish(pane_width int) {
	l := a.designer_layout_in(pane_width)
	drag := a.dz_drag
	match drag.kind {
		.widget, .chip {
			current := l.spec.widgets
			if drag.kind == .chip && !drag.moved() {
				// A tap on a chip: off the bar it goes on at the trailing end, as
				// the outermost control there; on the bar it comes off.
				next := if l.chips.any(it.action == drag.action && it.on_bar) {
					designer_apply(current, drag.action, DzDrop{ kind: .remove })
				} else {
					widgets_moved(current, drag.action, .trailing, 0)
				}
				a.desktop.settings.ov_widgets = int(widgets_pack(next))
				return
			}
			if !drag.moved() {
				return
			}
			drop := designer_drop(l, drag.action, drag.x, drag.y)
			if drop.kind != .cancel {
				a.desktop.settings.ov_widgets = int(widgets_pack(designer_apply(current, drag.action, drop)))
			}
		}
		.handle, .tab {
			a.designer_drag_live(pane_width)
		}
		else {}
	}
}

// ── The page ────────────────────────────────────────────────────────

fn (a &SettingsApp) appearance_tab_title(tab int) string {
	return match tab {
		appearance_tab_look { tr('settings.appearance.tab_look') }
		appearance_tab_title { tr('settings.appearance.tab_title') }
		appearance_tab_controls { tr('settings.appearance.tab_controls') }
		appearance_tab_actions { tr('settings.appearance.tab_actions') }
		appearance_tab_start { tr('settings.appearance.tab_start') }
		else { tr('settings.appearance.tab_skin') }
	}
}

fn (a &SettingsApp) appearance_pane(width int, height int) []ui2.Element {
	l := a.designer_layout_in(width)
	mut out := frame_elements(60)
	out << a.designer_elements(width)
	mut y := a.designer_bottom(l) + 8
	out << settings_note(tr('settings.designer.hint'), y, width)
	out << settings_note(tr('settings.designer.hint2'), y + 15, width)
	y += 38
	// The way back to what the look does on its own, at the foot of the page.
	out << settings_choice(settings_action_reset_chrome, tr('settings.windows.reset'), width - settings_padding - 150, height - 40, 150, false)

	// Sections.
	inner := width - 2 * settings_padding
	tab_w := (inner - (appearance_tab_count - 1) * 4) / appearance_tab_count
	for tab in 0 .. appearance_tab_count {
		out << settings_choice('${settings_action_atab}${tab}', a.appearance_tab_title(tab), settings_padding + tab * (tab_w + 4), y, tab_w,
			a.appearance_tab == tab)
	}
	y += 28 + 14
	match a.appearance_tab {
		appearance_tab_look { out << a.appearance_look(width, y) }
		appearance_tab_title { out << a.appearance_title(width, y) }
		appearance_tab_controls { out << a.appearance_controls(width, y) }
		appearance_tab_actions { out << a.appearance_actions(width, y) }
		appearance_tab_start { out << a.appearance_start_menu(width, y) }
		else { out << a.appearance_skin(width, y) }
	}
	return out
}

// settings_row_label is the fixed-width name at the start of a row of choices.
fn settings_row_label(text string, y int) ui2.Element {
	return ui2.label('', text, ui2.rect(f64(settings_padding), f64(y), 104, 28), ui2.TextStyle{
		color: body_text
		size: 12
		vertical_align: 'middle'
	})
}

// settings_row_choices lays count choices in one row after a row label, evenly,
// and calls make for each.
fn settings_row_x(width int, count int, index int) (int, int) {
	label_w := 104
	avail := width - 2 * settings_padding - label_w - settings_row_gap
	each := (avail - (count - 1) * 4) / count
	return settings_padding + label_w + settings_row_gap + index * (each + 4), each
}

fn (a &SettingsApp) appearance_look(width int, top int) []ui2.Element {
	settings := a.desktop.settings
	glass_offered := settings_glass_offered()
	luna_offered := settings_luna_offered()
	inner := width - 2 * settings_padding
	cols := 3
	each := (inner - (cols - 1) * 6) / cols
	mut out := []ui2.Element{cap: lookandfeel_registry.len + 3}
	mut y := top
	mut slot := 0
	for i, lnf in lookandfeel_registry {
		if (lnf.id == 'windows7' && !glass_offered) || (lnf.id == 'windowsxp' && !luna_offered) {
			continue
		}
		col := slot % cols
		out << settings_choice('${settings_action_theme}${i}', lnf.name, settings_padding + col * (each + 6), y, each,
			settings.preset_id == lnf.id)
		if col == cols - 1 {
			y += 28 + 6
		}
		slot++
	}
	if slot % cols != 0 {
		y += 28 + 6
	}
	y += 4
	out << settings_note(tr('settings.appearance.look_note'), y, width)
	return out
}

fn (a &SettingsApp) appearance_title(width int, top int) []ui2.Element {
	settings := a.desktop.settings
	mut out := []ui2.Element{cap: 24}
	mut y := top

	out << settings_row_label(tr('settings.windows.titlebar'), y)
	kind := settings.ov_title_kind
	for i, label in [tr('settings.windows.follow'), tr('settings.windows.bar'), tr('settings.windows.tab')] {
		x, w := settings_row_x(width, 3, i)
		selected := match i {
			0 { kind == none }
			1 { (kind or { TitleKind.tab }) == .full }
			else { (kind or { TitleKind.full }) == .tab }
		}
		out << settings_choice('${settings_action_title_kind}${i}', label, x, y, w, selected)
	}
	y += 34

	out << settings_row_label(tr('settings.windows.tab_position'), y)
	align := settings.ov_tab_align
	for i, label in [tr('settings.windows.follow'), tr('settings.windows.pos_left'), tr('settings.windows.pos_center'),
		tr('settings.windows.pos_right')] {
		x, w := settings_row_x(width, 4, i)
		selected := match i {
			0 { align == none }
			1 { (align or { TitleAlign.right }) == .left }
			2 { (align or { TitleAlign.left }) == .center }
			else { (align or { TitleAlign.left }) == .right }
		}
		out << settings_choice('${settings_action_tab_align}${i}', label, x, y, w, selected)
	}
	y += 34

	out << settings_row_label(tr('settings.appearance.tab_width'), y)
	for i, percent in settings_tab_width_choices {
		label := match percent {
			-1 { tr('settings.windows.follow') }
			0 { tr('settings.appearance.width_fit') }
			100 { tr('settings.appearance.width_full') }
			else { '${percent}%' }
		}
		x, w := settings_row_x(width, settings_tab_width_choices.len, i)
		selected := if percent == -1 {
			settings.ov_tab_width == none
		} else {
			(settings.ov_tab_width or { -2 }) == percent
		}
		out << settings_choice('${settings_action_tabwidth}${i}', label, x, y, w, selected)
	}
	y += 34

	out << settings_row_label(tr('settings.appearance.buttons'), y)
	for i, label in [tr('settings.appearance.side_look'), tr('settings.appearance.side_mirrored')] {
		x, w := settings_row_x(width, 2, i)
		out << settings_choice('${settings_action_side}${i}', label, x, y, w,
			(settings.button_side == .left) == (i == 1))
	}
	y += 34
	out << settings_note(tr('settings.appearance.buttons_note'), y, width)
	return out
}

fn (a &SettingsApp) appearance_controls(width int, top int) []ui2.Element {
	widgets := a.windows_pane_state().widgets
	mut out := []ui2.Element{cap: 24}
	mut y := top
	for action in settings_widget_actions {
		placement := widget_placement(widgets, action)
		out << settings_row_label(widget_action_title(action), y)
		for state in 0 .. 3 {
			text := match state {
				0 { tr('settings.windows.off') }
				1 { tr('settings.windows.pos_left') }
				else { tr('settings.windows.pos_right') }
			}
			x, w := settings_row_x(width, 3, state)
			out << settings_choice('${settings_action_widget}${widget_action_name(action)}.${state}', text, x, y, w,
				placement == state)
		}
		y += 32
	}
	out << settings_note(tr('settings.windows.widgets_note'), y + 2, width)
	return out
}

fn title_action_label(action TitleAction) string {
	return match action {
		.maximize { tr('settings.appearance.act_zoom') }
		.shade { tr('settings.appearance.act_shade') }
		.hide { tr('settings.appearance.act_minimize') }
		.none_ { tr('settings.appearance.act_none') }
	}
}

fn (a &SettingsApp) appearance_actions(width int, top int) []ui2.Element {
	settings := a.desktop.settings
	behavior := a.desktop.behavior()
	mut out := []ui2.Element{cap: 16}
	mut y := top
	rows := [
		[settings_action_title_dbl, tr('settings.appearance.double_click')],
		[settings_action_title_mid, tr('settings.appearance.middle_click')],
	]
	for row in rows {
		dbl := row[0] == settings_action_title_dbl
		chosen := if dbl { settings.ov_title_double_click } else { settings.ov_title_middle_click }
		effective := if dbl { behavior.title_double_click } else { behavior.title_middle_click }
		out << settings_row_label(row[1], y)
		for i in 0 .. settings_title_actions.len + 1 {
			label := if i == 0 {
				tr('settings.windows.follow')
			} else {
				title_action_label(settings_title_actions[i - 1])
			}
			x, w := settings_row_x(width, settings_title_actions.len + 1, i)
			selected := if i == 0 { chosen == none } else { (chosen or { effective }) == settings_title_actions[i - 1] && chosen != none }
			out << settings_choice('${row[0]}${i}', label, x, y, w, selected)
		}
		y += 34
	}
	out << settings_note(tr('settings.appearance.actions_note'), y + 4, width)
	return out
}

fn (a &SettingsApp) appearance_skin(width int, top int) []ui2.Element {
	settings := a.desktop.settings
	catalog := skin_catalog()
	inner := width - 2 * settings_padding
	third := (inner - 2 * settings_row_gap) / 3
	mut out := []ui2.Element{cap: catalog.len + 6}
	mut y := top
	out << settings_note(tr('settings.windows.skin_note'), y - 4, width)
	y += 18
	mut index := 0
	for choice in 0 .. catalog.len + 2 {
		label := if choice == 0 {
			tr('settings.windows.follow')
		} else if choice == 1 {
			tr('settings.windows.skin_none')
		} else {
			catalog[choice - 2].name
		}
		selected := if choice == 0 {
			settings.skin_id == ''
		} else if choice == 1 {
			settings.skin_id == 'none'
		} else {
			settings.skin_id == catalog[choice - 2].id
		}
		col := index % 3
		x := settings_padding + col * (third + settings_row_gap)
		out << settings_choice('${settings_action_skin}${choice}', label, x, y, third, selected)
		if col == 2 {
			y += 28 + 6
		}
		index++
	}
	if index % 3 != 0 {
		y += 28 + 6
	}
	// Where the themes are: the one in use, then the two folders to look in or
	// add to.
	text := skin_page_text(a.desktop.effective_skin_id())
	out << settings_note(text.in_use, y + 4, width)
	out << settings_note(text.installed, y + 22, width)
	out << settings_note(text.yours, y + 40, width)
	out << settings_note(tr('settings.appearance.skin_howto'), y + 62, width)
	return out
}

// SkinPageText is the page's three lines about where themes live. They are
// filled in once per theme in use and folder, not per frame: this process has
// no garbage collector, so a line built each frame would never go back.
struct SkinPageText {
mut:
	key       string
	in_use    string
	installed string
	yours     string
}

__global skin_page_cache = SkinPageText{}

fn skin_page_text(skin_id string) SkinPageText {
	installed_dir := skin_root()
	yours_dir := skin_user_root()
	key := '${skin_id}|${installed_dir}|${yours_dir}'
	if skin_page_cache.key == key && skin_page_cache.in_use.len > 0 {
		return skin_page_cache
	}
	mut name := tr('settings.windows.skin_none')
	mut where := ''
	for entry in skin_catalog() {
		if entry.id == skin_id {
			name = entry.name
			where = entry.dir
		}
	}
	if where.len == 0 {
		where = tr('settings.appearance.skin_builtin')
	}
	skin_page_cache = SkinPageText{
		key: key
		in_use: tr_substitute(tr('settings.appearance.skin_inuse'), name, where, '')
		installed: tr_substitute(tr('settings.appearance.skin_installed'), installed_dir, '', '')
		yours: tr_substitute(tr('settings.appearance.skin_yours'), yours_dir, '', '')
	}
	return skin_page_cache
}

// The Start menu's styles, in the order of StartMenuStyle: the look's own,
// then Windows, Fluxbox and the BeOS Deskbar.
fn start_menu_style_label(style StartMenuStyle) string {
	return match style {
		.follow_look { tr('settings.windows.follow') }
		.windows { tr('settings.start.windows') }
		.fluxbox { tr('settings.start.fluxbox') }
		.deskbar { tr('settings.start.deskbar') }
		.kmenu { tr('settings.start.kmenu') }
	}
}

fn (a &SettingsApp) appearance_start_menu(width int, top int) []ui2.Element {
	inner := width - 2 * settings_padding
	half := (inner - settings_row_gap) / 2
	mut out := []ui2.Element{cap: 8}
	mut y := top
	out << settings_note(tr('settings.appearance.start_note'), y - 4, width)
	y += 18
	for choice in 0 .. 5 {
		style := unsafe { StartMenuStyle(choice) }
		col := choice % 2
		x := if col == 0 { settings_padding } else { settings_padding + half + settings_row_gap }
		out << settings_choice('${settings_action_startmenu}${choice}', start_menu_style_label(style), x, y, half,
			a.desktop.settings.start_menu == style)
		if col == 1 {
			y += 28 + 6
		}
	}
	out << settings_note(tr('settings.appearance.start_resolved').replace('%s', start_menu_style_label(a.desktop.start_menu_style())), y + 4, width)
	return out
}
