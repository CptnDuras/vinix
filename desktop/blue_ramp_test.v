// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Tests for the Blue gray ramp (spec B1). Pure color math, no ui2.
module main

fn luminance(c u32) int {
	r := int((c >> 16) & 0xff)
	g := int((c >> 8) & 0xff)
	b := int(c & 0xff)
	return (r * 30 + g * 59 + b * 11) / 100
}

// (a) surfaces come from the ramp by role, not literals.
fn test_surface_roles_map_to_ramp_steps() {
	assert blue_ramp.surface(.window_body) == blue_ramp.steps[0]
	assert blue_ramp.surface(.panel) == blue_ramp.steps[1]
	assert blue_ramp.surface(.well) == blue_ramp.steps[3]
	assert blue_ramp.surface(.edge) == blue_ramp.steps[4]
	assert blue_ramp.surface(.text) == blue_ramp.steps[7]
	assert blue_ramp.surface(.shadow) == blue_ramp.steps[8]
}

// (b) changing the ramp changes all derived surfaces together.
fn test_retuning_ramp_moves_all_surfaces() {
	mut shifted := []u32{}
	for s in blue_ramp.steps {
		shifted << s & 0xfefefe // darken every step by one bit
	}
	other := Ramp{
		steps:  shifted
		accent: blue_ramp.accent
	}
	// Every role now differs from the original by the same rule.
	assert other.surface(.window_body) != blue_ramp.surface(.window_body)
	assert other.surface(.panel) != blue_ramp.surface(.panel)
	assert other.surface(.window_body) == blue_ramp.surface(.window_body) & 0xfefefe
}

// (c) bevel pairs are drawn from ramp steps, not independent constants.
fn test_bevel_pairs_come_from_ramp() {
	// A mid surface (index 2, the raised face) bevels with a lighter and darker
	// ramp step.
	bp := blue_ramp.bevel_pair_for(2)
	assert bp.light in blue_ramp.steps
	assert bp.dark in blue_ramp.steps
	assert luminance(bp.light) > luminance(bp.dark)
}

// Bevel derivation clamps at the ramp ends.
fn test_bevel_pairs_clamp_at_ends() {
	top := blue_ramp.bevel_pair_for(0) // lightest surface
	assert top.light == blue_ramp.steps[0] // cannot go lighter
	bottom := blue_ramp.bevel_pair_for(blue_ramp.steps.len - 1)
	assert bottom.dark == blue_ramp.steps[blue_ramp.steps.len - 1] // cannot go darker
}

// The ramp is monotonic: each step is darker than the previous.
fn test_ramp_is_monotonic() {
	for i in 1 .. blue_ramp.steps.len {
		assert luminance(blue_ramp.steps[i]) < luminance(blue_ramp.steps[i - 1])
	}
}

// The ramp is faintly cool at every step (blue >= red).
fn test_ramp_is_cool() {
	for s in blue_ramp.steps {
		assert ramp_step_is_cool(s)
	}
}

// The accent is distinct from every neutral step (it carries meaning).
fn test_accent_is_not_a_neutral_step() {
	assert blue_ramp.accent !in blue_ramp.steps
	// And it is actually blue-dominant, not neutral.
	r := int((blue_ramp.accent >> 16) & 0xff)
	b := int(blue_ramp.accent & 0xff)
	assert b > r + 40
}
