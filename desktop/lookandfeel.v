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
	// B4: cursor appearance (ISSUES.md GAP-11). The compositor draws its own
	// pointer; its colours fold into Decor so a preset can retheme it. Scope is
	// the fill/edge colours (a full cursor *shape* set is out of this cut).
	cursor_fill ?u32
	cursor_edge ?u32
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
	// D2: maximize / restore policy — whether a maximized window respects
	// occupied panel edges (a top bar and/or bottom taskbar).
	maximize_policy ?MaxPolicy
	// D4: focus model completeness (ISSUES.md GAP-7).
	focus_new_windows ?bool
	raise_on_focus    ?bool
	raise_on_click    ?bool
	// D5: window snapping & move/resize (ISSUES.md GAP-5).
	snap_to_edges      ?bool
	snap_to_windows    ?bool
	snap_distance      ?int
	opaque_move_resize ?bool
}

// ShellConfig — sparse Shell axis (spec E). Phase 1 carries only the coarse
// arrangement knobs needed by the resolver; the panel list is modelled in E.
struct ShellConfig {
	has_top_bar    ?bool
	has_bottom_bar ?bool
	// E3: whether the bottom bar hosts the window list (taskbar buttons). A
	// preset can omit it (classic Mac places no window list), leaving just the
	// system menu / clock. Defaults true so today's taskbar is unchanged.
	has_window_list ?bool
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
	order       int // display order in the picker
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
	cursor_fill   u32
	cursor_edge   u32
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
	maximize_policy    MaxPolicy
	focus_new_windows  bool
	raise_on_focus     bool
	raise_on_click     bool
	snap_to_edges      bool
	snap_to_windows    bool
	snap_distance      int
	opaque_move_resize bool
}

struct EffectiveShell {
	has_top_bar     bool
	has_bottom_bar  bool
	has_window_list bool
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
	window_body: 0xfbfcfe
	window_edge: 0xb9c2d0
	window_radius: 9
	accent: 0x5b9cf8
	title_align: .left
	// Today's compositor cursor (theme.v cursor_fill/cursor_edge). Kept as
	// literals here because the pure-logic model compiles without theme.v; a
	// standalone test guards that these still match the constants.
	cursor_fill: 0xffffff
	cursor_edge: 0x0d1220
}

const builtin_typography = EffectiveTypography{
	ui_size: 13
	title_size: 13
	smoothing: .grayscale
}

const builtin_behavior = EffectiveBehavior{
	shade_enabled: false
	title_double_click: .maximize
	focus_policy: .click_to_focus
	menu_placement: .none_
	// Default respects reserving panels. With the default shell (bottom taskbar
	// only) this subtracts exactly taskbar_height — reproducing today's
	// maximize — while a preset that adds a top bar has it respected too.
	maximize_policy: .respect_panels
	focus_new_windows: true
	raise_on_focus: true
	raise_on_click: true
	// Snapping off by default so behaviour is unchanged unless a preset opts in.
	snap_to_edges: false
	snap_to_windows: false
	snap_distance: 12
	opaque_move_resize: true
}

const builtin_shell = EffectiveShell{
	has_top_bar: false
	has_bottom_bar: true
	has_window_list: true
}

const builtin_surface = EffectiveSurface{
	wallpaper_color: 0
	wallpaper_image: -1
	icon_source: .shortcuts
	icons_visible: true
}

// ── The resolver (spec A2) ─────────────────────────────────────────
//
// Field-by-field merge with override → preset → default precedence. The V
// idiom `override or { preset or { default } }` is exactly the three-state
// resolution: each `?T` short-circuits to the next source when none.

fn resolve_config(preset LookAndFeel, overrides BlueSettings) EffectiveConfig {
	return EffectiveConfig{
		decor: resolve_decor(preset.decor, overrides.decor)
		typography: resolve_typography(preset.typography, overrides.typography)
		behavior: resolve_behavior(preset.behavior, overrides.behavior)
		shell: resolve_shell(preset.shell, overrides.shell)
		surface: resolve_surface(preset.surface, overrides.surface)
	}
}

fn resolve_decor(preset ?DecorConfig, over ?DecorConfig) EffectiveDecor {
	p := preset or { DecorConfig{} }
	o := over or { DecorConfig{} }
	return EffectiveDecor{
		window_body: o.window_body or { p.window_body or { builtin_decor.window_body } }
		window_edge: o.window_edge or { p.window_edge or { builtin_decor.window_edge } }
		window_radius: o.window_radius or { p.window_radius or { builtin_decor.window_radius } }
		accent: o.accent or { p.accent or { builtin_decor.accent } }
		title_align: o.title_align or { p.title_align or { builtin_decor.title_align } }
		cursor_fill: o.cursor_fill or { p.cursor_fill or { builtin_decor.cursor_fill } }
		cursor_edge: o.cursor_edge or { p.cursor_edge or { builtin_decor.cursor_edge } }
	}
}

fn resolve_typography(preset ?TypographyConfig, over ?TypographyConfig) EffectiveTypography {
	p := preset or { TypographyConfig{} }
	o := over or { TypographyConfig{} }
	return EffectiveTypography{
		ui_size: o.ui_size or { p.ui_size or { builtin_typography.ui_size } }
		title_size: o.title_size or { p.title_size or { builtin_typography.title_size } }
		smoothing: o.smoothing or { p.smoothing or { builtin_typography.smoothing } }
	}
}

fn resolve_behavior(preset ?BehaviorConfig, over ?BehaviorConfig) EffectiveBehavior {
	p := preset or { BehaviorConfig{} }
	o := over or { BehaviorConfig{} }
	return EffectiveBehavior{
		shade_enabled: o.shade_enabled or { p.shade_enabled or { builtin_behavior.shade_enabled } }
		title_double_click: o.title_double_click or { p.title_double_click or { builtin_behavior.title_double_click } }
		focus_policy: o.focus_policy or { p.focus_policy or { builtin_behavior.focus_policy } }
		menu_placement: o.menu_placement or { p.menu_placement or { builtin_behavior.menu_placement } }
		maximize_policy: o.maximize_policy or { p.maximize_policy or { builtin_behavior.maximize_policy } }
		focus_new_windows: o.focus_new_windows or { p.focus_new_windows or { builtin_behavior.focus_new_windows } }
		raise_on_focus: o.raise_on_focus or { p.raise_on_focus or { builtin_behavior.raise_on_focus } }
		raise_on_click: o.raise_on_click or { p.raise_on_click or { builtin_behavior.raise_on_click } }
		snap_to_edges: o.snap_to_edges or { p.snap_to_edges or { builtin_behavior.snap_to_edges } }
		snap_to_windows: o.snap_to_windows or { p.snap_to_windows or { builtin_behavior.snap_to_windows } }
		snap_distance: o.snap_distance or { p.snap_distance or { builtin_behavior.snap_distance } }
		opaque_move_resize: o.opaque_move_resize or { p.opaque_move_resize or { builtin_behavior.opaque_move_resize } }
	}
}

fn resolve_shell(preset ?ShellConfig, over ?ShellConfig) EffectiveShell {
	p := preset or { ShellConfig{} }
	o := over or { ShellConfig{} }
	return EffectiveShell{
		has_top_bar: o.has_top_bar or { p.has_top_bar or { builtin_shell.has_top_bar } }
		has_bottom_bar: o.has_bottom_bar or { p.has_bottom_bar or { builtin_shell.has_bottom_bar } }
		has_window_list: o.has_window_list or { p.has_window_list or { builtin_shell.has_window_list } }
	}
}

fn resolve_surface(preset ?DesktopSurfaceConfig, over ?DesktopSurfaceConfig) EffectiveSurface {
	p := preset or { DesktopSurfaceConfig{} }
	o := over or { DesktopSurfaceConfig{} }
	return EffectiveSurface{
		wallpaper_color: o.wallpaper_color or { p.wallpaper_color or { builtin_surface.wallpaper_color } }
		wallpaper_image: o.wallpaper_image or { p.wallpaper_image or { builtin_surface.wallpaper_image } }
		icon_source: o.icon_source or { p.icon_source or { builtin_surface.icon_source } }
		icons_visible: o.icons_visible or { p.icons_visible or { builtin_surface.icons_visible } }
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
		id: 'blue'
		name: 'Blue'
		description: 'A calm, cool-neutral look with structural depth: subtle bevels, one reserved accent, and modern anti-aliased type.'
		order: 0
		decor: DecorConfig{
			window_radius: 3
			accent: 0x3b74d6
			title_align: .left
		}
		behavior: BehaviorConfig{
			shade_enabled: true
			menu_placement: .in_window
			// Blue enables edge/window snapping with a modest threshold.
			snap_to_edges: true
			snap_to_windows: true
			snap_distance: 12
		}
		shell: ShellConfig{
			has_top_bar: true
			has_bottom_bar: true
		}
	},
	LookAndFeel{
		id: 'default'
		name: 'Default'
		description: 'Rounded windows with shadows and flat colour, and a taskbar across the bottom.'
		order: 1
	},
	LookAndFeel{
		id: 'macos'
		name: 'macOS'
		description: 'Light grey windows with the title centred, three coloured discs at the leading edge, and a dock.'
		order: 2
		decor: DecorConfig{
			window_body: 0xffffff
			window_edge: 0x9a9a9a
			window_radius: 6
			title_align: .center
		}
	},
	LookAndFeel{
		id: 'win2k'
		name: 'Windows 2000'
		description: 'Warm-neutral grey with raised/sunken bevels, a blue gradient title, square corners, and one bottom taskbar.'
		order: 3
		decor: DecorConfig{
			window_radius: 0
			accent: 0x0a246a
			title_align: .left
		}
		behavior: BehaviorConfig{
			title_double_click: .maximize
			menu_placement: .in_window
		}
		shell: ShellConfig{
			has_top_bar: false
			has_bottom_bar: true
		}
	},
	LookAndFeel{
		id: 'platinum'
		name: 'Platinum'
		description: 'Cool grey Mac OS Platinum: a quiet centred title, grooved dividers, and a global menu bar across the top.'
		order: 4
		decor: DecorConfig{
			window_radius: 2
			title_align: .center
		}
		behavior: BehaviorConfig{
			title_double_click: .shade
			menu_placement: .global_
		}
		shell: ShellConfig{
			has_top_bar: true
			has_bottom_bar: false
		}
	},
	LookAndFeel{
		id: 'beos'
		name: 'BeOS'
		description: 'Restrained light grey with a yellow title accent and tight spacing; the Deskbar folds system menu and window list into one corner.'
		order: 5
		decor: DecorConfig{
			window_radius: 0
			accent: 0xffce00
			title_align: .left
		}
		behavior: BehaviorConfig{
			shade_enabled: true
			title_double_click: .shade
			menu_placement: .in_window
			// BeOS classically offered focus-follows-mouse; the pointer focuses
			// the window under it without raising it.
			focus_policy: .focus_follows_mouse
			raise_on_focus: false
		}
		shell: ShellConfig{
			has_top_bar: true
			has_bottom_bar: false
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
		id: default_preset_id
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
