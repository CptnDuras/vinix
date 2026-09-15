// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for window-shade (spec D1). Pure state transitions, no ui2.
module main

const title_h = 30

// (a) shading stores the prior height and collapses to the title bar.
fn test_shade_collapses_and_stores() {
	s := ShadeState{ height: 400, shaded: false }
	after := shade_toggle(s, title_h, true)
	assert after.shaded
	assert after.height == title_h
	assert after.restore_height_shade == 400
}

// (b) unshading restores the exact prior height.
fn test_unshade_restores_height() {
	s := ShadeState{ height: 400 }
	shaded := shade_toggle(s, title_h, true)
	restored := shade_toggle(shaded, title_h, true)
	assert !restored.shaded
	assert restored.height == 400
}

// (c) a shaded window's body is not visible/hit-tested.
fn test_shaded_body_hidden() {
	s := ShadeState{ height: 400 }
	shaded := shade_toggle(s, title_h, true)
	assert !shaded_body_visible(shaded)
	assert shaded_body_visible(s)
}

// (d) shade is a no-op when disabled.
fn test_shade_noop_when_disabled() {
	s := ShadeState{ height: 400, shaded: false }
	after := shade_toggle(s, title_h, false)
	assert after == s
}

// A disabled toggle still un-shades an already-shaded window (so disabling the
// feature cannot trap a window rolled up).
fn test_disabled_can_still_unshade() {
	shaded := ShadeState{ height: title_h, shaded: true, restore_height_shade: 250 }
	after := shade_toggle(shaded, title_h, false)
	assert !after.shaded
	assert after.height == 250
}

// Round-trip is idempotent in height.
fn test_shade_round_trip_idempotent() {
	s := ShadeState{ height: 512 }
	r := shade_toggle(shade_toggle(s, title_h, true), title_h, true)
	assert r.height == s.height
	assert r.shaded == s.shaded
}
