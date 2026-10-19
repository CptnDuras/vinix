// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// The title bar designer in Settings > Appearance: a miniature window whose
// title bar the user rearranges by dragging. This file is the geometry and the
// rules only, with no ui2 and no desktop, so what a drop does is tested without
// a screen. settings_designer.v draws it and feeds it the pointer.
module main

struct DzRect {
	x int
	y int
	w int
	h int
}

fn (r DzRect) contains(px int, py int) bool {
	return px >= r.x && px < r.x + r.w && py >= r.y && py < r.y + r.h
}

fn (r DzRect) inflated(by int) DzRect {
	return DzRect{
		x: r.x - by
		y: r.y - by
		w: r.w + 2 * by
		h: r.h + 2 * by
	}
}

// DzMetrics are the measurements a designer is laid out with; they come from
// the look in force, so the miniature has the real bar's proportions.
struct DzMetrics {
	bar_h          int = 24
	widget_size    int = 16
	widget_gap     int = 4
	widget_inset   int = 6
	title_w        int = 48
	body_h         int = 44
	chip_h         int = 24
	chip_gap       int = 6
	handle_w       int = 8
	drop_slop      int = 12
}

// DzPlaced is one control of the bar with the rectangle it occupies.
struct DzPlaced {
	action WidgetAction
	anchor WidgetAnchor
	rect   DzRect
}

// DzChip is one entry of the tray under the miniature: every control a bar can
// have, whether or not it is on the bar now.
struct DzChip {
	action WidgetAction
	on_bar bool
	rect   DzRect
}

struct DzLayout {
	frame   DzRect
	bar     DzRect
	body    DzRect
	tray    DzRect
	placed  []DzPlaced
	chips   []DzChip
	// handle is the grip a tab is resized by, on the edge facing the window's
	// middle (it straddles that edge); it is empty for a bar across the window.
	handle  DzRect
	is_tab  bool
	spec    ChromeSpec
	metrics DzMetrics
}

// designer_actions lists every control in the order the tray shows them.
const designer_actions = [WidgetAction.close, .minimize, .maximize, .shade, .menu]

// designer_layout lays the miniature out inside the rectangle (x, y, w) it is
// given; its height follows from the metrics.
fn designer_layout(spec ChromeSpec, x int, y int, w int, m DzMetrics) DzLayout {
	is_tab := spec.kind == .tab
	frame := DzRect{
		x: x
		y: y
		w: w
		h: m.bar_h + m.body_h
	}
	mut bar := DzRect{
		x: x
		y: y
		w: w
		h: m.bar_h
	}
	if is_tab {
		content := widget_extent(spec.widgets, .leading, m.widget_size, m.widget_gap) +
			widget_extent(spec.widgets, .trailing, m.widget_size, m.widget_gap) + m.title_w +
			2 * m.widget_inset
		tw := tab_width(spec, w, content)
		bar = DzRect{
			x: x + tab_x(spec, w, tw)
			y: y
			w: tw
			h: m.bar_h
		}
	}
	slots := layout_widgets(spec.widgets, bar.w, bar.h, m.widget_size, m.widget_gap, m.widget_inset)
	mut placed := []DzPlaced{cap: slots.len}
	for slot in slots {
		wd := spec.widgets[slot.index]
		placed << DzPlaced{
			action: wd.action
			anchor: wd.anchor
			rect: DzRect{
				x: bar.x + slot.x
				y: bar.y + slot.y
				w: slot.size
				h: slot.size
			}
		}
	}
	body := DzRect{
		x: x
		y: y + m.bar_h
		w: w
		h: m.body_h
	}
	tray := DzRect{
		x: x
		y: y + frame.h + 10
		w: w
		h: m.chip_h
	}
	// The tray's chips share its width evenly.
	count := designer_actions.len
	chip_w := (w - (count - 1) * m.chip_gap) / count
	mut chips := []DzChip{cap: count}
	for i, action in designer_actions {
		on_bar := spec.widgets.any(it.action == action)
		chips << DzChip{
			action: action
			on_bar: on_bar
			rect: DzRect{
				x: tray.x + i * (chip_w + m.chip_gap)
				y: tray.y
				w: chip_w
				h: m.chip_h
			}
		}
	}
	mut handle := DzRect{}
	if is_tab {
		// The grip straddles the tab's edge that faces the middle of the window,
		// mostly outside it so it stays clear of the tab's own controls: the
		// right edge for a left or centred tab, the left one for a right tab.
		on_left := spec.tab_align == .right
		handle = DzRect{
			x: if on_left { bar.x - (m.handle_w - 3) } else { bar.x + bar.w - 3 }
			y: bar.y
			w: m.handle_w
			h: bar.h
		}
	}
	return DzLayout{
		frame: frame
		bar: bar
		body: body
		tray: tray
		placed: placed
		chips: chips
		handle: handle
		is_tab: is_tab
		spec: spec
		metrics: m
	}
}

enum DzHitKind {
	nothing
	widget
	chip
	handle
	tab
	bar
}

struct DzHit {
	kind   DzHitKind
	action WidgetAction
}

// designer_hit says what is under (px, py): a control on the bar, a chip of the
// tray, the tab's grip, the tab or bar itself, or nothing. Controls win over the
// grip, and the grip over the tab, since each sits on top of the next.
fn designer_hit(l DzLayout, px int, py int) DzHit {
	for p in l.placed {
		if p.rect.inflated(2).contains(px, py) {
			return DzHit{
				kind: .widget
				action: p.action
			}
		}
	}
	for c in l.chips {
		if c.rect.contains(px, py) {
			return DzHit{
				kind: .chip
				action: c.action
			}
		}
	}
	if l.is_tab && l.handle.contains(px, py) {
		return DzHit{
			kind: .handle
		}
	}
	if l.bar.contains(px, py) {
		return DzHit{
			kind: if l.is_tab { DzHitKind.tab } else { DzHitKind.bar }
		}
	}
	return DzHit{}
}

enum DzDropKind {
	cancel // nothing changes
	place  // the control goes to the bar at anchor and position
	remove // the control comes off the bar
}

struct DzDrop {
	kind     DzDropKind
	anchor   WidgetAnchor
	position int
}

// designer_drop decides what releasing a dragged control at (px, py) does. On
// the bar it is placed: at the end of the bar the pointer is nearer, as the
// position-th control from the outside among the others there. Over the tray it
// comes off the bar. Anywhere else the drag is abandoned.
fn designer_drop(l DzLayout, dragged WidgetAction, px int, py int) DzDrop {
	slop := l.metrics.drop_slop
	target := if l.is_tab { l.bar } else { l.bar }
	if target.inflated(slop).contains(px, py) {
		anchor := if px < target.x + target.w / 2 {
			WidgetAnchor.leading
		} else {
			WidgetAnchor.trailing
		}
		mut position := 0
		for p in l.placed {
			if p.action == dragged || p.anchor != anchor {
				continue
			}
			centre := p.rect.x + p.rect.w / 2
			// Controls the pointer has passed on the way in from the outside
			// come before it.
			if (anchor == .leading && centre < px) || (anchor == .trailing && centre > px) {
				position++
			}
		}
		return DzDrop{
			kind: .place
			anchor: anchor
			position: position
		}
	}
	if l.tray.inflated(slop).contains(px, py) {
		return DzDrop{
			kind: .remove
		}
	}
	return DzDrop{}
}

// designer_apply performs a drop on a list of controls.
fn designer_apply(widgets []WidgetSpec, dragged WidgetAction, drop DzDrop) []WidgetSpec {
	return match drop.kind {
		.place { widgets_moved(widgets, dragged, drop.anchor, drop.position) }
		// A bar keeps at least one control, so a window can always be closed.
		.remove { if widgets.len <= 1 { widgets } else { widgets_removed(widgets, dragged) } }
		.cancel { widgets }
	}
}

// designer_tab_percent is the tab width dragging its grip to px asks for, as a
// percentage of the window's width in steps of five and never under ten. Past
// the window's far edge it is the whole width.
fn designer_tab_percent(l DzLayout, px int) int {
	if l.frame.w <= 0 {
		return 100
	}
	raw := match l.spec.tab_align {
		.left { px - l.frame.x }
		.right { l.frame.x + l.frame.w - px }
		// A centred tab grows on both sides, so its half-width is the distance
		// from the middle.
		.center { 2 * (px - (l.frame.x + l.frame.w / 2)) }
	}
	mut pct := (raw * 100 + l.frame.w / 2) / l.frame.w
	pct = (pct + 2) / 5 * 5
	if pct < 10 {
		pct = 10
	}
	if pct > 100 {
		pct = 100
	}
	return pct
}

// designer_tab_align is the alignment a tab dragged so its middle is at px
// belongs to: whichever of left, centre and right puts the tab's middle nearest.
fn designer_tab_align(l DzLayout, px int) TitleAlign {
	half := l.bar.w / 2
	left_mid := l.frame.x + half
	centre_mid := l.frame.x + l.frame.w / 2
	right_mid := l.frame.x + l.frame.w - half
	dl := absi(px - left_mid)
	dc := absi(px - centre_mid)
	dr := absi(px - right_mid)
	if dc <= dl && dc <= dr {
		return .center
	}
	return if dl < dr { TitleAlign.left } else { TitleAlign.right }
}

fn absi(v int) int {
	return if v < 0 { -v } else { v }
}

// designer_insertion_x is where the bar's drop marker is drawn for a drop: the
// edge of the control the dropped one lands beside, or the bar's end when the
// run is empty or it lands last. It lets the miniature show the result before
// the button is released.
fn designer_insertion_x(l DzLayout, dragged WidgetAction, drop DzDrop) int {
	if drop.kind != .place {
		return -1
	}
	m := l.metrics
	mut run := []DzPlaced{}
	for p in l.placed {
		if p.action != dragged && p.anchor == drop.anchor {
			run << p
		}
	}
	if drop.anchor == .leading {
		if drop.position < run.len {
			return run[drop.position].rect.x - m.widget_gap / 2
		}
		return if run.len > 0 {
			run[run.len - 1].rect.x + run[run.len - 1].rect.w + m.widget_gap / 2
		} else {
			l.bar.x + m.widget_inset
		}
	}
	if drop.position < run.len {
		return run[drop.position].rect.x + run[drop.position].rect.w + m.widget_gap / 2
	}
	return if run.len > 0 {
		run[run.len - 1].rect.x - m.widget_gap / 2
	} else {
		l.bar.x + l.bar.w - m.widget_inset
	}
}
