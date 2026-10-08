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
		'win2k' { theme_win2k }
		'platinum' { theme_platinum }
		'beos' { theme_beos }
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

// behavior resolves the current preset's window-handling policy (Blue spec D).
// Until per-axis user overrides are threaded into Settings, this resolves the
// selected preset against empty overrides. The WM reads this for shade,
// focus, maximize policy, etc.
fn (d &Desktop) behavior() EffectiveBehavior {
	eff := resolve_settings(d.settings.blue_overrides())
	return eff.behavior
}

// shell resolves the current preset's shell arrangement (Blue spec E): whether
// a top bar and/or bottom bar are present, plus the user's per-axis overrides.
fn (d &Desktop) shell() EffectiveShell {
	eff := resolve_settings(d.settings.blue_overrides())
	return eff.shell
}

// surface resolves the desktop-surface axis (Blue spec H): wallpaper selection,
// desktop-icon source, and icon visibility.
//
// The user's live wallpaper selection (held in the existing `Settings` fields
// the picker writes) is fed in as the override so it still wins over a
// preset-supplied backdrop (H1 acceptance (c)); when the user has made no
// explicit choice, a preset backdrop shows through (H1 acceptance (b)). The
// per-axis icon overrides (source/visibility) are threaded alongside it.
fn (d &Desktop) surface() EffectiveSurface {
	// Start from the projected per-axis overrides (icon source/visibility), then
	// layer the dedicated wallpaper selection on top. A chosen image (>= 0) or a
	// non-default colour index is an explicit user override; the image sentinel
	// is -1 (no image) and colour index 0 is the built-in default.
	mut over := d.settings.blue_overrides()
	icon := over.surface or { DesktopSurfaceConfig{} }
	over.surface = if d.settings.wallpaper_image >= 0 {
		DesktopSurfaceConfig{
			icon_source:     icon.icon_source
			icons_visible:   icon.icons_visible
			wallpaper_image: d.settings.wallpaper_image
		}
	} else if d.settings.wallpaper_color != 0 {
		DesktopSurfaceConfig{
			icon_source:     icon.icon_source
			icons_visible:   icon.icons_visible
			wallpaper_color: d.settings.wallpaper_color
			wallpaper_image: -1
		}
	} else {
		icon
	}
	eff := resolve_settings(over)
	return eff.surface
}

// typography resolves the Typography axis (Blue spec C1): UI/title point sizes
// and smoothing, with the user's per-axis overrides applied. render.v and the
// title chrome read this for text sizing.
fn (d &Desktop) typography() EffectiveTypography {
	eff := resolve_settings(d.settings.blue_overrides())
	return eff.typography
}

// decor resolves the Decorations axis (Blue spec B), with the user's per-axis
// overrides applied. The renderer reads this for the cursor colours (B4); the
// full chrome migration still flows through preset_theme() until every Theme
// field lands in Decor.
fn (d &Desktop) decor() EffectiveDecor {
	eff := resolve_settings(d.settings.blue_overrides())
	return eff.decor
}
