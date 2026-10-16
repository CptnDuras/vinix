// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for the focus model (spec D4). Pure predicates, no ui2. FocusPolicy is
// defined in lookandfeel.v.
module main

// (a) click_to_focus: a bare move changes nothing.
fn test_click_to_focus_ignores_moves() {
	d := decide_focus(FocusInputs{ is_click: false, over_window_id: 5, current_focus: 2 },
		.click_to_focus, true, true)
	assert d.new_focus == 2
	assert !d.raise
}

// (a') click_to_focus: a body click focuses; raises only if raise_on_click.
fn test_click_to_focus_body_click() {
	yes := decide_focus(FocusInputs{ is_click: true, over_window_id: 5, frame_body_hit: true },
		.click_to_focus, true, true)
	assert yes.new_focus == 5
	assert yes.raise
	no := decide_focus(FocusInputs{ is_click: true, over_window_id: 5, frame_body_hit: true },
		.click_to_focus, true, false)
	assert no.new_focus == 5
	assert !no.raise // raise_on_click=false and it was a body hit
}

// A decoration click always raises regardless of raise_on_click.
fn test_decoration_click_always_raises() {
	d := decide_focus(FocusInputs{ is_click: true, over_window_id: 5, frame_body_hit: false },
		.click_to_focus, false, false)
	assert d.raise
}

// (b) focus_follows_mouse: moving over a window focuses it without raising when
// raise_on_focus is false.
fn test_follows_mouse_focus_without_raise() {
	d := decide_focus(FocusInputs{ is_click: false, over_window_id: 7, current_focus: 1 },
		.focus_follows_mouse, false, false)
	assert d.new_focus == 7
	assert !d.raise
}

// (c) raise_on_focus makes a follows-mouse move raise as well.
fn test_follows_mouse_raise_on_focus() {
	d := decide_focus(FocusInputs{ is_click: false, over_window_id: 7 },
		.focus_follows_mouse, true, false)
	assert d.new_focus == 7
	assert d.raise
}

// No window under the pointer never raises "nothing".
fn test_no_window_no_raise() {
	d := decide_focus(FocusInputs{ is_click: false, over_window_id: 0 },
		.focus_follows_mouse, true, true)
	assert d.new_focus == 0
	assert !d.raise
}
