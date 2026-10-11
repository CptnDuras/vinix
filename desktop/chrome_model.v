// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Window chrome model (Blue spec B5, blue-specs/window-chrome.md).
//
// Pure data and layout: no ui2, no Theme. wm.v turns a ChromeSpec into
// elements; this file decides what exists and where. Keeping the geometry here
// lets the tab and widget rules be tested without a canvas.
module main

// TitleKind is the shape of a window's title bar.
enum TitleKind {
	full // the bar spans the window's width, as in nearly every look
	tab  // a bar shorter than the window, sitting on its top edge (BeOS)
}

// TabSizing says how wide a tab is.
enum TabSizing {
	fit      // as wide as the title and the widgets need
	fixed    // tab_px wide
	fraction // tab_pct percent of the window's width
}

// WidgetAction is what a title bar widget does when pressed.
enum WidgetAction {
	close
	minimize
	maximize
	shade
	menu
}

// WidgetAnchor is the end of the bar a widget is placed from. Within an anchor,
// widgets are placed outermost first.
enum WidgetAnchor {
	leading
	trailing
}

// WidgetShape is how a widget's face is drawn when it has no skin.
enum WidgetShape {
	square // the flat button of the stock look
	disc   // a round, coloured control
}

// WidgetSpec is one control in a window's title bar.
struct WidgetSpec {
	action WidgetAction
	anchor WidgetAnchor
	shape  WidgetShape
	// size is the control's side in pixels; 0 takes the theme's button size.
	size int
	// A skin names a vector or a bitmap for the widget; see skin.v. Empty draws
	// the shape procedurally.
	skin string
}

// ChromeSpec describes a window's chrome. The zero value is "derive everything
// from the theme": a full-width bar and the three stock buttons.
struct ChromeSpec {
	kind        TitleKind
	tab_sizing  TabSizing
	tab_px      int
	tab_pct     int
	tab_align   TitleAlign
	tab_pad     int = 10
	tab_overlap int
	// tab_slant makes the tab's two upper corners lean in by this many pixels.
	tab_slant int
	// widgets, when not empty, replaces the stock buttons.
	widgets []WidgetSpec
	// The skin this look wears unless the user picks another; see skin.v.
	skin string
}

// WidgetSlot is a widget with its place in the bar, in the bar's own
// coordinates.
struct WidgetSlot {
	index int // into the spec's widget list
	x     int
	y     int
	size  int
}

// widget_action_name is the part name a widget's element id ends in.
fn widget_action_name(action WidgetAction) string {
	return match action {
		.close { 'close' }
		.minimize { 'minimize' }
		.maximize { 'maximize' }
		.shade { 'shade' }
		.menu { 'menu' }
	}
}

// widget_size is a widget's side, taking the default when it names none.
fn widget_size(w WidgetSpec, default_size int) int {
	return if w.size > 0 { w.size } else { default_size }
}

// stock_widgets is the set every look had before widgets were data: close,
// then minimise and zoom, from whichever end the buttons live at. Close is
// outermost for flat buttons, as both conventions have it; traffic lights keep
// their red-yellow-green reading order at either end.
fn stock_widgets(traffic bool, buttons_left bool) []WidgetSpec {
	shape := if traffic { WidgetShape.disc } else { WidgetShape.square }
	anchor := if buttons_left { WidgetAnchor.leading } else { WidgetAnchor.trailing }
	mut out := []WidgetSpec{cap: 3}
	if traffic || buttons_left {
		out << WidgetSpec{ action: .close, anchor: anchor, shape: shape }
		out << WidgetSpec{ action: .minimize, anchor: anchor, shape: shape }
		out << WidgetSpec{ action: .maximize, anchor: anchor, shape: shape }
	} else {
		out << WidgetSpec{ action: .close, anchor: anchor, shape: shape }
		out << WidgetSpec{ action: .maximize, anchor: anchor, shape: shape }
		out << WidgetSpec{ action: .minimize, anchor: anchor, shape: shape }
	}
	// A traffic set at the trailing end is placed outermost first, so reverse it
	// to keep close leftmost of the three.
	if traffic && !buttons_left {
		out.reverse_in_place()
	}
	return out
}

// widget_extent is the room a run of widgets takes: their sizes and the gaps
// between them, but not the inset before the first.
fn widget_extent(widgets []WidgetSpec, anchor WidgetAnchor, default_size int, gap int) int {
	mut total := 0
	mut count := 0
	for w in widgets {
		if w.anchor != anchor {
			continue
		}
		total += widget_size(w, default_size)
		count++
	}
	if count > 1 {
		total += (count - 1) * gap
	}
	return total
}

// layout_widgets places every widget in a bar bar_w wide and bar_h tall. Leading
// widgets run in from the left edge, trailing ones in from the right, each
// outermost first, and each is centred on the bar's height.
fn layout_widgets(widgets []WidgetSpec, bar_w int, bar_h int, default_size int, gap int, inset int) []WidgetSlot {
	mut out := []WidgetSlot{cap: widgets.len}
	mut lead_x := inset
	mut trail_x := bar_w - inset
	for i, w in widgets {
		size := widget_size(w, default_size)
		y := (bar_h - size) / 2
		if w.anchor == .leading {
			out << WidgetSlot{ index: i, x: lead_x, y: y, size: size }
			lead_x += size + gap
		} else {
			trail_x -= size
			out << WidgetSlot{ index: i, x: trail_x, y: y, size: size }
			trail_x -= gap
		}
	}
	return out
}

// tab_width is how wide a tab is for a window window_w across. content is what
// a fit tab must hold: its title and its widgets.
fn tab_width(spec ChromeSpec, window_w int, content int) int {
	raw := match spec.tab_sizing {
		.fit { content + 2 * spec.tab_pad }
		.fixed { spec.tab_px }
		.fraction { window_w * spec.tab_pct / 100 }
	}
	mut w := raw
	if w > window_w {
		w = window_w
	}
	if w < 1 {
		w = 1
	}
	return w
}

// tab_x is where a tab of width tab_w starts along a window window_w across.
fn tab_x(spec ChromeSpec, window_w int, tab_w int) int {
	return match spec.tab_align {
		.left { 0 }
		.center { (window_w - tab_w) / 2 }
		.right { window_w - tab_w }
	}
}

fn maxi(a int, b int) int {
	return if a > b { a } else { b }
}

fn widget_action_from_name(name string) ?WidgetAction {
	return match name {
		'close' { WidgetAction.close }
		'minimize' { WidgetAction.minimize }
		'maximize' { WidgetAction.maximize }
		'shade' { WidgetAction.shade }
		'menu' { WidgetAction.menu }
		else { none }
	}
}

fn title_align_from_text(name string) ?TitleAlign {
	return match name {
		'left' { TitleAlign.left }
		'center' { TitleAlign.center }
		'right' { TitleAlign.right }
		else { none }
	}
}

// widgets_from_text reads "close@leading,maximize@trailing,..." into widgets,
// in order. Any entry it cannot read, or more than max_widgets of them, makes
// the whole list unusable.
const max_widgets = 7

fn widgets_from_text(text string) ?[]WidgetSpec {
	mut out := []WidgetSpec{}
	if text.trim_space().len == 0 {
		return out
	}
	for item in text.split(',') {
		parts := item.trim_space().split('@')
		if parts.len != 2 {
			return none
		}
		action := widget_action_from_name(parts[0]) or { return none }
		anchor := match parts[1] {
			'leading' { WidgetAnchor.leading }
			'trailing' { WidgetAnchor.trailing }
			else { return none }
		}
		out << WidgetSpec{
			action: action
			anchor: anchor
		}
		if out.len > max_widgets {
			return none
		}
	}
	return out
}

// widgets_to_text is the inverse of widgets_from_text.
fn widgets_to_text(widgets []WidgetSpec) string {
	mut parts := []string{}
	for w in widgets {
		anchor := if w.anchor == .leading { 'leading' } else { 'trailing' }
		parts << '${widget_action_name(w.action)}@${anchor}'
	}
	return parts.join(',')
}

// A widget list carried in one u32: four bits each, up to seven, in order, with
// zero ending the list. Bit 3 is the anchor (set = trailing) and bits 0..2 are
// the action plus one. This is the form the application protocol and the
// preferences file's overrides share, so neither needs a variable-length field.
fn widgets_pack(widgets []WidgetSpec) u32 {
	mut v := u32(0)
	for i, w in widgets {
		if i >= max_widgets {
			break
		}
		code := u32(int(w.action) + 1) | if w.anchor == .trailing { u32(8) } else { u32(0) }
		v |= code << u32(4 * i)
	}
	return v
}

fn widgets_unpack(v u32) []WidgetSpec {
	mut out := []WidgetSpec{}
	for i in 0 .. max_widgets {
		code := (v >> u32(4 * i)) & 0xf
		if code == 0 {
			break
		}
		action := int(code & 7) - 1
		if action < 0 || action > int(WidgetAction.menu) {
			return []WidgetSpec{}
		}
		out << WidgetSpec{
			action: unsafe { WidgetAction(action) }
			anchor: if code & 8 != 0 { WidgetAnchor.trailing } else { WidgetAnchor.leading }
		}
	}
	return out
}

// chrome_apply_key sets one field of a ChromeSpec from its text name and value,
// as skin.cfg's `chrome.*` lines spell it. It reports whether it understood.
fn chrome_apply_key(mut spec ChromeSpec, key string, value string) bool {
	match key {
		'kind' {
			spec = ChromeSpec{
				...spec
				kind: match value {
					'full' { TitleKind.full }
					'tab' { TitleKind.tab }
					else { return false }
				}
			}
		}
		'tab_sizing' {
			spec = ChromeSpec{
				...spec
				tab_sizing: match value {
					'fit' { TabSizing.fit }
					'fixed' { TabSizing.fixed }
					'fraction' { TabSizing.fraction }
					else { return false }
				}
			}
		}
		'tab_align' {
			a := title_align_from_text(value) or { return false }
			spec = ChromeSpec{
				...spec
				tab_align: a
			}
		}
		'tab_px', 'tab_pct', 'tab_pad', 'tab_overlap', 'tab_slant' {
			if value.len == 0 || !value.bytes().all(it >= `0` && it <= `9`) || value.len > 4 {
				return false
			}
			n := value.int()
			spec = match key {
				'tab_px' { ChromeSpec{ ...spec, tab_px: n } }
				'tab_pct' { ChromeSpec{ ...spec, tab_pct: if n > 100 { 100 } else { n } } }
				'tab_pad' { ChromeSpec{ ...spec, tab_pad: n } }
				'tab_overlap' { ChromeSpec{ ...spec, tab_overlap: n } }
				else { ChromeSpec{ ...spec, tab_slant: n } }
			}
		}
		'widgets' {
			w := widgets_from_text(value) or { return false }
			spec = ChromeSpec{
				...spec
				widgets: w
			}
		}
		else {
			return false
		}
	}
	return true
}

fn title_kind_name(k TitleKind) string {
	return match k {
		.full { 'full' }
		.tab { 'tab' }
	}
}

fn title_kind_from(name string) ?TitleKind {
	return match name {
		'full' { TitleKind.full }
		'tab' { TitleKind.tab }
		else { none }
	}
}
