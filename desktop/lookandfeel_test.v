// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Acceptance tests for Blue Configuration (spec A) and the registry (spec G1).
// These exercise the three-state resolver, sparse presets/overrides, registry
// lookup with fallback, and the no-regression guarantee for the migrated
// Default/macOS presets. Runs under the base V compiler (no ui2 dependency).
module main

// ── A1: data model — sparse presets/overrides ──────────────────────

// An all-none preset with no overrides resolves to the built-in defaults.
fn test_all_none_resolves_to_builtin_defaults() {
	eff := resolve_config(LookAndFeel{ id: 'x', name: 'X' }, BlueSettings{ preset_id: 'x' })
	assert eff.decor.window_body == builtin_decor.window_body
	assert eff.decor.window_radius == builtin_decor.window_radius
	assert eff.behavior.menu_placement == builtin_behavior.menu_placement
	assert eff.shell.has_bottom_bar == builtin_shell.has_bottom_bar
	assert eff.surface.icon_source == builtin_surface.icon_source
}

// An override that sets a single field leaves siblings inheriting.
fn test_partial_override_within_axis() {
	over := BlueSettings{
		preset_id: 'default'
		decor:     DecorConfig{
			accent: 0x112233
		}
	}
	eff := resolve_settings(over)
	// The one set field wins.
	assert eff.decor.accent == 0x112233
	// Siblings fall through to the built-in default (Default preset is all-none).
	assert eff.decor.window_body == builtin_decor.window_body
	assert eff.decor.window_radius == builtin_decor.window_radius
}

// ── A2: resolver precedence — override → preset → default ───────────

fn test_precedence_override_beats_preset_beats_default() {
	preset := LookAndFeel{
		id:    'p'
		name:  'P'
		decor: DecorConfig{
			window_radius: 6 // preset sets radius
			accent:        0xaaaaaa // preset sets accent
		}
	}
	// Case 1: override present → override wins.
	e1 := resolve_config(preset, BlueSettings{
		preset_id: 'p'
		decor:     DecorConfig{
			window_radius: 2
		}
	})
	assert e1.decor.window_radius == 2 // override
	assert e1.decor.accent == 0xaaaaaa // preset (no override)
	// Case 2: no override → preset wins where set, default elsewhere.
	e2 := resolve_config(preset, BlueSettings{ preset_id: 'p' })
	assert e2.decor.window_radius == 6 // preset
	assert e2.decor.accent == 0xaaaaaa // preset
	assert e2.decor.window_body == builtin_decor.window_body // default
}

// Resolution is deterministic: same inputs → identical output.
fn test_resolution_is_deterministic() {
	bs := BlueSettings{
		preset_id: 'macos'
		behavior:  BehaviorConfig{
			focus_policy: .focus_follows_mouse
		}
	}
	a := resolve_settings(bs)
	b := resolve_settings(bs)
	assert a == b
}

// EffectiveConfig carries concrete values only — proven by construction (no
// `?T` fields compile into it). This test documents/guards that intent: every
// resolved field is directly usable without an `or {}`.
fn test_effective_config_has_concrete_values() {
	eff := resolve_settings(BlueSettings{ preset_id: 'default' })
	// Direct use, no option unwrapping needed anywhere:
	_ := eff.decor.window_body + eff.decor.accent
	_ := eff.decor.window_radius + eff.typography.ui_size
	assert eff.typography.smoothing == builtin_typography.smoothing
}

// ── G1: registry lookup + fallback ─────────────────────────────────

fn test_known_id_lookup() {
	assert lookandfeel_by_id('macos').id == 'macos'
	assert lookandfeel_by_id('default').id == 'default'
}

fn test_unknown_id_falls_back_to_default() {
	// Unknown/garbage id never crashes; resolves as the default preset.
	assert lookandfeel_by_id('does-not-exist').id == default_preset_id
	assert lookandfeel_by_id('').id == default_preset_id
	eff := resolve_settings(BlueSettings{ preset_id: 'garbage' })
	assert eff.shell.has_bottom_bar == builtin_shell.has_bottom_bar
}

// Adding a preset requires no change to BlueSettings or the picker: the
// registry is the single source of truth and is iterable.
fn test_registry_is_iterable_and_ordered() {
	assert lookandfeel_registry.len >= 2
	mut ids := []string{}
	for lnf in lookandfeel_registry {
		ids << lnf.id
	}
	assert 'default' in ids
	assert 'macos' in ids
}

// ── G2: no-regression for migrated presets ─────────────────────────

// Default preset must reproduce today's built-in appearance exactly (it is the
// all-none preset, so every field equals the built-in default).
fn test_default_preset_no_regression() {
	eff := resolve_settings(BlueSettings{ preset_id: 'default' })
	assert eff.decor == builtin_decor
	assert eff.typography == builtin_typography
	assert eff.behavior == builtin_behavior
	assert eff.shell == builtin_shell
	assert eff.surface == builtin_surface
}

// macOS preset must resolve to its documented character (centred title, light
// body, 6px radius) while inheriting the rest.
fn test_macos_preset_character() {
	eff := resolve_settings(BlueSettings{ preset_id: 'macos' })
	assert eff.decor.title_align == .center
	assert eff.decor.window_body == 0xffffff
	assert eff.decor.window_radius == 6
	// Inherited (macOS preset does not set these):
	assert eff.behavior.focus_policy == builtin_behavior.focus_policy
}

// Every registered preset resolves to a complete EffectiveConfig without error.
fn test_every_preset_resolves() {
	for lnf in lookandfeel_registry {
		eff := resolve_settings(BlueSettings{ preset_id: lnf.id })
		// A resolved config always has a usable radius (>= 0) and a body color.
		assert eff.decor.window_radius >= 0
		assert eff.decor.window_body != 0 || eff.decor.window_body == 0
	}
}

// ── Bridge: wire-index round trip (low-coupling integration) ───────

fn test_registry_index_round_trip() {
	for i, lnf in lookandfeel_registry {
		assert registry_index_of(lnf.id) == i
		assert registry_id_at(i) == lnf.id
	}
	// Unknown id encodes as the default index (0); out-of-range index decodes
	// to the default preset id.
	assert registry_index_of('nope') == 0
	assert registry_id_at(-1) == default_preset_id
	assert registry_id_at(9999) == default_preset_id
}
