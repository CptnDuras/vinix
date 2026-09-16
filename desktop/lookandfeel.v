// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue look-and-feel — Configuration (spec A).
//
// The three-state configuration model that underlies every other Blue feature.
// Presets and user overrides are sparse optionals (`?T`), resolved field-by-
// field into a single fully-resolved `EffectiveConfig`. The renderer and window
// manager only ever read an `EffectiveConfig`; they never inspect presets or
// overrides directly.
//
// Resolution order for every axis field (spec A):
//     effective(field) = user_override(field)      if set
//                      = active_preset.value(field) else if the preset sets it
//                      = built-in default           otherwise
//
// See desktop/blue-specs/configuration.md. This file implements A1 (data model),
// A2 (resolver semantics) and the registry mechanism (G1). Persistence (A3) and
// the wiring of `Desktop.theme()` are separate integration steps.
module main

// ── Axes (sparse: every field is optional) ─────────────────────────
//
// Phase 1 models the subset of each axis needed to exercise the three-state
// resolver end to end. Later phases widen these structs; because every field is
// `?T`, widening never forces a migration — a newly added field is `none`
// everywhere and inherits its built-in default.

// DecorConfig — sparse Decorations axis (spec B).
struct DecorConfig {
	window_body   ?u32
	window_edge   ?u32
	window_radius ?int
	accent        ?u32
	title_align   ?TitleAlign
}

// TypographyConfig — sparse Typography axis (spec C).
struct TypographyConfig {
	ui_size    ?int
	title_size ?int
	smoothing  ?Smoothing
}

// BehaviorConfig — sparse Window-handling axis (spec D). Carries menu_placement
// (the Menu system F owns no axis of its own).
struct BehaviorConfig {
	shade_enabled      ?bool
	title_double_click ?TitleAction
	focus_policy       ?FocusPolicy
	menu_placement     ?MenuPlacement
}

// ShellConfig — sparse Shell axis (spec E). Phase 1 carries only the coarse
// arrangement knobs needed by the resolver; the panel list is modelled in E.
struct ShellConfig {
	has_top_bar    ?bool
	has_bottom_bar ?bool
}

// DesktopSurfaceConfig — sparse Desktop-surface axis (spec H).
struct DesktopSurfaceConfig {
	wallpaper_color ?int
	wallpaper_image ?int
	icon_source     ?IconSource
	icons_visible   ?bool
}

// ── Axis enums ─────────────────────────────────────────────────────

enum TitleAlign {
	left
	center
	right
}

enum Smoothing {
	none_
	grayscale
	subpixel
}

enum TitleAction {
	shade
	hide
	maximize
	none_
}

enum FocusPolicy {
	click_to_focus
	focus_follows_mouse
}

enum MenuPlacement {
	global_
	in_window
	none_
}

enum IconSource {
	shortcuts
	files
}

// ── LookAndFeel: one preset in the registry ────────────────────────
//
// A preset is sparse: it sets only the axes that define its character and
// leaves the rest `none` so they inherit built-in defaults.

struct LookAndFeel {
	id          string // stable key; the selection key. Never reordered-sensitive.
	name        string // shown in the picker
	description string // shown in the picker (replaces hardcoded branches)
	order       int    // display order in the picker
	decor       ?DecorConfig
	typography  ?TypographyConfig
	behavior    ?BehaviorConfig
	shell       ?ShellConfig
	surface     ?DesktopSurfaceConfig
}

// BlueSettings: the user's saved look-and-feel state. `preset_id` selects a
// registry entry; each axis override is independently optional ("not set").
// This is the Blue-owned portion of the desktop's settings; it is merged into
// the existing `Settings` at the persistence/integration step (A3).
struct BlueSettings {
mut:
	preset_id  string = default_preset_id
	decor      ?DecorConfig
	typography ?TypographyConfig
	behavior   ?BehaviorConfig
	shell      ?ShellConfig
	surface    ?DesktopSurfaceConfig
}

// ── EffectiveConfig: fully resolved, no optionals ──────────────────
//
// The renderer/WM read only this. Every field is concrete: the resolver has
// already applied override → preset → default for each one.

struct EffectiveDecor {
	window_body   u32
	window_edge   u32
	window_radius int
	accent        u32
	title_align   TitleAlign
}

struct EffectiveTypography {
	ui_size    int
	title_size int
	smoothing  Smoothing
}

struct EffectiveBehavior {
	shade_enabled      bool
	title_double_click TitleAction
	focus_policy       FocusPolicy
	menu_placement     MenuPlacement
}

struct EffectiveShell {
	has_top_bar    bool
	has_bottom_bar bool
}

struct EffectiveSurface {
	wallpaper_color int
	wallpaper_image int
	icon_source     IconSource
	icons_visible   bool
}

struct EffectiveConfig {
	decor      EffectiveDecor
	typography EffectiveTypography
	behavior   EffectiveBehavior
	shell      EffectiveShell
	surface    EffectiveSurface
}

// ── Built-in defaults ──────────────────────────────────────────────
//
// The final fallback when neither an override nor the preset sets a field.
// These reproduce today's desktop appearance/behaviour so an all-none preset
// and no overrides yield no visual change.

const builtin_decor = EffectiveDecor{
	window_body:   0xfbfcfe
	window_edge:   0xb9c2d0
	window_radius: 9
	accent:        0x5b9cf8
	title_align:   .left
}

const builtin_typography = EffectiveTypography{
	ui_size:    13
	title_size: 13
	smoothing:  .grayscale
}

const builtin_behavior = EffectiveBehavior{
	shade_enabled:      false
	title_double_click: .maximize
	focus_policy:       .click_to_focus
	menu_placement:     .none_
}

const builtin_shell = EffectiveShell{
	has_top_bar:    false
	has_bottom_bar: true
}

const builtin_surface = EffectiveSurface{
	wallpaper_color: 0
	wallpaper_image: -1
	icon_source:     .shortcuts
	icons_visible:   true
}

// ── The resolver (spec A2) ─────────────────────────────────────────
//
// Field-by-field merge with override → preset → default precedence. The V
// idiom `override or { preset or { default } }` is exactly the three-state
// resolution: each `?T` short-circuits to the next source when none.

fn resolve_config(preset LookAndFeel, overrides BlueSettings) EffectiveConfig {
	return EffectiveConfig{
		decor:      resolve_decor(preset.decor, overrides.decor)
		typography: resolve_typography(preset.typography, overrides.typography)
		behavior:   resolve_behavior(preset.behavior, overrides.behavior)
		shell:      resolve_shell(preset.shell, overrides.shell)
		surface:    resolve_surface(preset.surface, overrides.surface)
	}
}

fn resolve_decor(preset ?DecorConfig, over ?DecorConfig) EffectiveDecor {
	p := preset or { DecorConfig{} }
	o := over or { DecorConfig{} }
	return EffectiveDecor{
		window_body:   o.window_body or { p.window_body or { builtin_decor.window_body } }
		window_edge:   o.window_edge or { p.window_edge or { builtin_decor.window_edge } }
		window_radius: o.window_radius or { p.window_radius or { builtin_decor.window_radius } }
		accent:        o.accent or { p.accent or { builtin_decor.accent } }
		title_align:   o.title_align or { p.title_align or { builtin_decor.title_align } }
	}
}

fn resolve_typography(preset ?TypographyConfig, over ?TypographyConfig) EffectiveTypography {
	p := preset or { TypographyConfig{} }
	o := over or { TypographyConfig{} }
	return EffectiveTypography{
		ui_size:    o.ui_size or { p.ui_size or { builtin_typography.ui_size } }
		title_size: o.title_size or { p.title_size or { builtin_typography.title_size } }
		smoothing:  o.smoothing or { p.smoothing or { builtin_typography.smoothing } }
	}
}

fn resolve_behavior(preset ?BehaviorConfig, over ?BehaviorConfig) EffectiveBehavior {
	p := preset or { BehaviorConfig{} }
	o := over or { BehaviorConfig{} }
	return EffectiveBehavior{
		shade_enabled:      o.shade_enabled or { p.shade_enabled or { builtin_behavior.shade_enabled } }
		title_double_click: o.title_double_click or { p.title_double_click or { builtin_behavior.title_double_click } }
		focus_policy:       o.focus_policy or { p.focus_policy or { builtin_behavior.focus_policy } }
		menu_placement:     o.menu_placement or { p.menu_placement or { builtin_behavior.menu_placement } }
	}
}

fn resolve_shell(preset ?ShellConfig, over ?ShellConfig) EffectiveShell {
	p := preset or { ShellConfig{} }
	o := over or { ShellConfig{} }
	return EffectiveShell{
		has_top_bar:    o.has_top_bar or { p.has_top_bar or { builtin_shell.has_top_bar } }
		has_bottom_bar: o.has_bottom_bar or { p.has_bottom_bar or { builtin_shell.has_bottom_bar } }
	}
}

fn resolve_surface(preset ?DesktopSurfaceConfig, over ?DesktopSurfaceConfig) EffectiveSurface {
	p := preset or { DesktopSurfaceConfig{} }
	o := over or { DesktopSurfaceConfig{} }
	return EffectiveSurface{
		wallpaper_color: o.wallpaper_color or { p.wallpaper_color or { builtin_surface.wallpaper_color } }
		wallpaper_image: o.wallpaper_image or { p.wallpaper_image or { builtin_surface.wallpaper_image } }
		icon_source:     o.icon_source or { p.icon_source or { builtin_surface.icon_source } }
		icons_visible:   o.icons_visible or { p.icons_visible or { builtin_surface.icons_visible } }
	}
}

// ── The registry (spec G1) ─────────────────────────────────────────
//
// A single list of presets keyed by stable string id. Lookup falls back to the
// default preset when an id is unknown, so a stale/garbage `preset_id` can
// never crash resolution. Adding a preset needs no change to BlueSettings or
// the picker: they iterate the registry.

const default_preset_id = 'default'

// The reference presets. Phase 1 migrates the existing Default and macOS looks
// in as sparse presets so there is no visual regression. Later phases add Blue
// and the era presets. Default is intentionally all-none: it *is* the built-in
// default, so it inherits every field.
const lookandfeel_registry = [
	LookAndFeel{
		id:          'blue'
		name:        'Blue'
		description: 'A calm, cool-neutral look with structural depth: subtle bevels, one reserved accent, and modern anti-aliased type.'
		order:       0
		decor:       DecorConfig{
			window_radius: 3
			accent:        0x3b74d6
			title_align:   .left
		}
		behavior:    BehaviorConfig{
			shade_enabled:  true
			menu_placement: .in_window
		}
		shell:       ShellConfig{
			has_top_bar:    true
			has_bottom_bar: true
		}
	},
	LookAndFeel{
		id:          'default'
		name:        'Default'
		description: 'Rounded windows with shadows and flat colour, and a taskbar across the bottom.'
		order:       1
	},
	LookAndFeel{
		id:          'macos'
		name:        'macOS'
		description: 'Light grey windows with the title centred, three coloured discs at the leading edge, and a dock.'
		order:       2
		decor:       DecorConfig{
			window_body:   0xffffff
			window_edge:   0x9a9a9a
			window_radius: 6
			title_align:   .center
		}
	},
]

// lookandfeel_by_id returns the preset with the given id, or the default preset
// when the id is unknown (never fails).
fn lookandfeel_by_id(id string) LookAndFeel {
	for lnf in lookandfeel_registry {
		if lnf.id == id {
			return lnf
		}
	}
	return lookandfeel_default()
}

// lookandfeel_default returns the preset used as the resolution fallback.
fn lookandfeel_default() LookAndFeel {
	for lnf in lookandfeel_registry {
		if lnf.id == default_preset_id {
			return lnf
		}
	}
	// The registry is authored to always contain the default id; if that
	// invariant is ever broken, fall back to an empty preset rather than
	// crashing (all fields then resolve to built-in defaults).
	return LookAndFeel{
		id:   default_preset_id
		name: 'Default'
	}
}

// resolve_settings is the top-level entry: pick the selected preset by id and
// resolve it against the user's overrides. This is what the desktop calls once
// per settings change to obtain the EffectiveConfig it renders from.
fn resolve_settings(bs BlueSettings) EffectiveConfig {
	preset := lookandfeel_by_id(bs.preset_id)
	return resolve_config(preset, bs)
}
