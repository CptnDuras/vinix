// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Decorations — palette & gray ramp (spec B1).
//
// The spine of the Blue look: one tuned neutral scale with a faint, consistent
// cool temperature, from which every chrome surface, edge, hover shade and
// bevel pair is *derived* — not chosen independently. Retuning the ramp
// restyles the whole system coherently. A single reserved accent carries
// meaning (focus/selection); almost nothing else is colored.
//
// Pure color math, no ui2 — unit-tested against the derivation rules.
module main

// Ramp is an ordered neutral scale from near-white (step 0) to near-black
// (last step), plus the reserved accent. Steps are 0xRRGGBB.
struct Ramp {
	steps  []u32
	accent u32
}

// SurfaceRole names the logical surfaces the chrome draws, each mapped to a
// ramp step by rule (see ramp_role_index). This is the indirection that keeps
// the palette coherent: code asks for a role, not a hex value.
enum SurfaceRole {
	window_body // the lightest working surface
	panel       // slightly darker than body — bars, sidebars
	well        // a sunken input area
	edge        // window/border outline
	hover       // hover shade over a surface
	shadow      // the darkest step, used at low alpha
	text        // body text (dark)
	text_muted  // secondary text
}

// blue_ramp is the flagship neutral scale. Nine steps, faintly cool: the blue
// channel leads the red channel by a few points at every step, which reads as
// a calm, slightly cool gray rather than a dead neutral. Tuned by eye; the
// exact values are expected to be adjusted against a screenshot.
const blue_ramp = Ramp{
	steps: [
		u32(0xf7f8fa), // 0 near-white — window body
		u32(0xeef0f3), // 1 panel
		u32(0xe4e7ec), // 2 hover / raised face
		u32(0xd6dae1), // 3 well / light bevel base
		u32(0xbcc2cc), // 4 edge
		u32(0x9aa2ae), // 5
		u32(0x6b7280), // 6 muted text
		u32(0x3a4049), // 7 body text
		u32(0x1c1f24), // 8 near-black — shadow
	]
	accent: 0x3b74d6 // the one reserved accent — a calm, slightly desaturated blue
}

// ramp_role_index maps a surface role to a ramp step index. This is the single
// place the "which step is which surface" decision lives.
fn ramp_role_index(role SurfaceRole) int {
	return match role {
		.window_body { 0 }
		.panel { 1 }
		.hover { 2 }
		.well { 3 }
		.edge { 4 }
		.text_muted { 6 }
		.text { 7 }
		.shadow { 8 }
	}
}

// ramp_surface returns the color for a logical surface role.
fn (r Ramp) surface(role SurfaceRole) u32 {
	idx := ramp_role_index(role)
	if idx < 0 || idx >= r.steps.len {
		return 0
	}
	return r.steps[idx]
}

// BevelPair is the (light, dark) pair used to bevel a surface. Both are ramp
// steps: the light is a step lighter than the surface, the dark a step (or
// two) darker, so raised/sunken edges stay in the same coherent scale.
struct BevelPair {
	light u32
	dark  u32
}

// bevel_pair_for derives the highlight/shadow for a surface at ramp index
// `surface_idx`: light = one step toward white, dark = two steps toward black,
// clamped to the ramp ends. This keeps bevels tied to the ramp rather than to
// independent constants (spec B1 acceptance (c)).
fn (r Ramp) bevel_pair_for(surface_idx int) BevelPair {
	last := r.steps.len - 1
	mut li := surface_idx - 1
	if li < 0 {
		li = 0
	}
	mut di := surface_idx + 2
	if di > last {
		di = last
	}
	return BevelPair{
		light: r.steps[li]
		dark:  r.steps[di]
	}
}

// ramp_is_cool reports whether a step is faintly cool (blue channel >= red
// channel). Used by the palette test to assert the ramp's temperature.
fn ramp_step_is_cool(color u32) bool {
	red := (color >> 16) & 0xff
	blue := color & 0xff
	return blue >= red
}
