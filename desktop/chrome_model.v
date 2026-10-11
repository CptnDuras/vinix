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
