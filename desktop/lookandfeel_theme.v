// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Bridge between the Blue look-and-feel registry (spec A/G) and the existing
// `Theme` struct that the window manager and renderer read today.
//
// This is the low-coupling integration step: theme *selection* becomes
// registry-driven by stable string id, while the concrete `Theme` values are
// still the existing `theme_default` / `theme_macos`. The full migration of
// `Theme`'s fields into a resolved `EffectiveConfig` happens in the
// Decorations phase (spec B); until then, `Desktop.theme()` maps a `preset_id`
// to a `Theme` here.
//
// Kept in its own file (separate from lookandfeel.v) so the resolver's unit
// tests can compile the pure model without pulling in the `Theme` type that
// lives in the desktop's `module main`.
module main

// preset_theme returns the concrete `Theme` for a registry id. Unknown ids
// fall back to the default look, matching lookandfeel_by_id's contract.
fn preset_theme(id string) Theme {
	return match id {
		'blue' { theme_blue }
		'macos' { theme_macos }
		else { theme_default }
	}
}

// registry_index_of returns the position of a preset id in the registry, or 0
// (the default) when unknown. Used to carry the selection across the fixed-size
// app IPC wire as a small integer without introducing variable-length strings.
fn registry_index_of(id string) int {
	for i, lnf in lookandfeel_registry {
		if lnf.id == id {
			return i
		}
	}
	return 0
}

// registry_id_at returns the preset id at a wire index, clamping out-of-range
// indices to the default preset id.
fn registry_id_at(index int) string {
	if index < 0 || index >= lookandfeel_registry.len {
		return default_preset_id
	}
	return lookandfeel_registry[index].id
}
