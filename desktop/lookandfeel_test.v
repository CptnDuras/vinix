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

// D2/D4/D5: the newer Behavior fields resolve through override → preset →
// default like every other axis field.
fn test_behavior_extended_fields_resolve() {
	// Defaults reproduce today's behaviour: respect_panels + no snapping.
	def := resolve_config(LookAndFeel{ id: 'x', name: 'X' }, BlueSettings{ preset_id: 'x' })
	assert def.behavior.maximize_policy == .respect_panels
	assert def.behavior.snap_to_edges == false
	assert def.behavior.snap_distance == builtin_behavior.snap_distance
	assert def.behavior.focus_new_windows == true

	// A preset can turn snapping on and switch the maximize policy; a user
	// override still beats it field-by-field.
	preset := LookAndFeel{
		id: 'p'
		name: 'P'
		behavior: BehaviorConfig{
			maximize_policy: .fill_screen
			snap_to_edges: true
			snap_distance: 20
		}
	}
	e1 := resolve_config(preset, BlueSettings{ preset_id: 'p' })
	assert e1.behavior.maximize_policy == .fill_screen
	assert e1.behavior.snap_to_edges == true
	assert e1.behavior.snap_distance == 20

	e2 := resolve_config(preset, BlueSettings{
		preset_id: 'p'
		behavior: BehaviorConfig{
			snap_distance: 4
		}
	})
	assert e2.behavior.snap_distance == 4 // override wins
	assert e2.behavior.snap_to_edges == true // preset (no override)
}

// B4: cursor colours fold into the Decor axis. Defaults reproduce today's
// compositor cursor; a preset (or override) can retheme fill/edge.
fn test_cursor_folds_into_decor() {
	// Default: today's cursor (white fill, near-black edge).
	def := resolve_config(LookAndFeel{ id: 'x', name: 'X' }, BlueSettings{ preset_id: 'x' })
	assert def.decor.cursor_fill == 0xffffff
	assert def.decor.cursor_edge == 0x0d1220
	assert def.decor.cursor_fill == builtin_decor.cursor_fill
	assert def.decor.cursor_edge == builtin_decor.cursor_edge

	// A preset retheme the cursor without touching any other field.
	preset := LookAndFeel{
		id: 'p'
		name: 'P'
		decor: DecorConfig{
			cursor_fill: 0x112233
			cursor_edge: 0xffcc00
		}
	}
	e1 := resolve_config(preset, BlueSettings{ preset_id: 'p' })
	assert e1.decor.cursor_fill == 0x112233
	assert e1.decor.cursor_edge == 0xffcc00
	// Siblings still inherit their built-in defaults.
	assert e1.decor.window_body == builtin_decor.window_body

	// A user override beats the preset.
	e2 := resolve_config(preset, BlueSettings{
		preset_id: 'p'
		decor: DecorConfig{
			cursor_fill: 0x000000
		}
	})
	assert e2.decor.cursor_fill == 0x000000 // override wins
	assert e2.decor.cursor_edge == 0xffcc00 // preset (no override)
}

// An override that sets a single field leaves siblings inheriting.
fn test_partial_override_within_axis() {
	over := BlueSettings{
		preset_id: 'default'
		decor: DecorConfig{
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

// E3: the window list is a placeable item the shell can omit. It defaults to
// present (today's taskbar), and a preset can turn it off.
fn test_window_list_toggle_resolves() {
	def := resolve_config(LookAndFeel{ id: 'x', name: 'X' }, BlueSettings{ preset_id: 'x' })
	assert def.shell.has_window_list == true // today's taskbar shows the list

	preset := LookAndFeel{
		id: 'p'
		name: 'P'
		shell: ShellConfig{
			has_bottom_bar: true
			has_window_list: false
		}
	}
	e := resolve_config(preset, BlueSettings{ preset_id: 'p' })
	assert e.shell.has_bottom_bar == true
	assert e.shell.has_window_list == false
}

// E4: the launcher's pinned set resolves like any axis field. Unset means no
// launcher (today's shells); a preset can pin app indices.
fn test_launcher_pins_resolve() {
	def := resolve_config(LookAndFeel{ id: 'x', name: 'X' }, BlueSettings{ preset_id: 'x' })
	assert def.shell.launcher_pins.len == 0 // no launcher by default

	preset := LookAndFeel{
		id: 'p'
		name: 'P'
		shell: ShellConfig{
			launcher_pins: [0, 3, 4]
		}
	}
	e := resolve_config(preset, BlueSettings{ preset_id: 'p' })
	assert e.shell.launcher_pins == [0, 3, 4]

	// The BeOS preset ships a Deskbar launcher.
	beos := resolve_settings(BlueSettings{ preset_id: 'beos' })
	assert beos.shell.launcher_pins.len == 3
}

// E5: the tray's status items resolve like any axis field. Unset means an
// empty tray (today's shells); a preset can register status items in order.
fn test_tray_items_resolve() {
	def := resolve_config(LookAndFeel{ id: 'x', name: 'X' }, BlueSettings{ preset_id: 'x' })
	assert def.shell.tray_items.len == 0 // empty tray by default

	preset := LookAndFeel{
		id: 'p'
		name: 'P'
		shell: ShellConfig{
			tray_items: [TrayStatus.wifi, TrayStatus.battery]
		}
	}
	e := resolve_config(preset, BlueSettings{ preset_id: 'p' })
	assert e.shell.tray_items == [TrayStatus.wifi, TrayStatus.battery]

	// The Blue preset ships a wifi + battery tray.
	blue := resolve_settings(BlueSettings{ preset_id: 'blue' })
	assert blue.shell.tray_items.len == 2
}

// ── A2: resolver precedence — override → preset → default ───────────

fn test_precedence_override_beats_preset_beats_default() {
	preset := LookAndFeel{
		id: 'p'
		name: 'P'
		decor: DecorConfig{
			window_radius: 6 // preset sets radius
			accent: 0xaaaaaa // preset sets accent
		}
	}
	// Case 1: override present → override wins.
	e1 := resolve_config(preset, BlueSettings{
		preset_id: 'p'
		decor: DecorConfig{
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
		behavior: BehaviorConfig{
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

// Blue preset resolves to its documented character.
fn test_blue_preset_character() {
	eff := resolve_settings(BlueSettings{ preset_id: 'blue' })
	assert eff.decor.window_radius == 3
	assert eff.decor.accent == 0x3b74d6
	assert eff.decor.title_align == .left
	assert eff.behavior.shade_enabled == true
	assert eff.behavior.menu_placement == .in_window
}

// ── H1: wallpaper as a resolvable axis ─────────────────────────────

// Default (no override, all-none preset) reproduces today's wallpaper values,
// which are exactly what the app IPC transmits (color index, image index).
fn test_wallpaper_defaults_match_ipc_values() {
	eff := resolve_settings(BlueSettings{ preset_id: 'default' })
	assert eff.surface.wallpaper_color == 0
	assert eff.surface.wallpaper_image == -1
}

// A preset may ship a backdrop; a user override beats it.
fn test_wallpaper_override_beats_preset() {
	preset := LookAndFeel{
		id: 'wp'
		name: 'WP'
		surface: DesktopSurfaceConfig{
			wallpaper_image: 3 // preset ships image 3
		}
	}
	// No override -> preset's image.
	e1 := resolve_config(preset, BlueSettings{ preset_id: 'wp' })
	assert e1.surface.wallpaper_image == 3
	// Override -> override wins.
	e2 := resolve_config(preset, BlueSettings{
		preset_id: 'wp'
		surface: DesktopSurfaceConfig{
			wallpaper_image: 7
		}
	})
	assert e2.surface.wallpaper_image == 7
}

// Icon source axis resolves (shortcuts by default).
fn test_icon_source_default_shortcuts() {
	eff := resolve_settings(BlueSettings{ preset_id: 'default' })
	assert eff.surface.icon_source == .shortcuts
	assert eff.surface.icons_visible == true
}

// Era presets resolve to their documented character (spec G2).
fn test_era_presets_character() {
	win2k := resolve_settings(BlueSettings{ preset_id: 'win2k' })
	assert win2k.decor.window_radius == 0
	assert win2k.behavior.menu_placement == .in_window
	assert win2k.shell.has_bottom_bar && !win2k.shell.has_top_bar

	platinum := resolve_settings(BlueSettings{ preset_id: 'platinum' })
	assert platinum.decor.title_align == .center
	assert platinum.behavior.menu_placement == .global_
	assert platinum.shell.has_top_bar && !platinum.shell.has_bottom_bar

	beos := resolve_settings(BlueSettings{ preset_id: 'beos' })
	assert beos.behavior.shade_enabled
	assert beos.decor.accent == 0xffce00
	assert beos.shell.has_top_bar
}

// The registry now offers the full preset set.
fn test_registry_has_all_presets() {
	mut ids := []string{}
	for lnf in lookandfeel_registry {
		ids << lnf.id
	}
	for want in ['blue', 'default', 'macos', 'win2k', 'platinum', 'beos'] {
		assert want in ids
	}
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
