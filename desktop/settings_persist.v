// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Configuration — persistence & migration (spec A3).
//
// The desktop's user settings (the selected look-and-feel preset and the
// per-axis overrides the picker writes) serialize to a small, line-based text
// blob and load back. The format is deliberately sparse: **a field that is at
// its built-in default is not written at all**, and an absent key loads as the
// default ("not set" is an absent key, never a sentinel). This is exactly the
// three-state model's disk form — clearing an override (reset) simply drops its
// key, and the field re-inherits on the next load.
//
// The blob is pure text so it can be reasoned about and round-tripped without
// touching the filesystem; wm.v wraps encode/decode with the tiny
// desktop_read_file/desktop_write_file POSIX boundary the desktop already uses.
//
// Migration: there is no legacy on-disk settings format (settings were
// in-memory only before Blue), so a missing/garbage blob simply loads the
// built-in defaults. A future legacy `ThemeKind` integer, if one is ever
// found, maps through registry_id_at() — see decode_settings.
module main

// The keys written to the blob. Kept as constants so encode and decode cannot
// drift, and so a typo is a compile error rather than a silent default.
const settings_key_preset = 'preset'
const settings_key_wallpaper_color = 'wallpaper_color'
const settings_key_wallpaper_image = 'wallpaper_image'
const settings_key_button_side = 'button_side'
const settings_key_taskbar_mode = 'taskbar_mode'
// Per-axis override keys (Blue spec A3/G3). Each is written only when the user
// has set that override; an absent key is "not set" and re-inherits on load.
const settings_key_ov_window_radius = 'ov_window_radius'
const settings_key_ov_title_align = 'ov_title_align'
const settings_key_ov_ui_size = 'ov_ui_size'
const settings_key_ov_title_size = 'ov_title_size'
const settings_key_ov_shade_enabled = 'ov_shade_enabled'
const settings_key_ov_menu_placement = 'ov_menu_placement'
const settings_key_ov_title_double_click = 'ov_title_double_click'
const settings_key_ov_has_top_bar = 'ov_has_top_bar'
const settings_key_ov_has_bottom_bar = 'ov_has_bottom_bar'
const settings_key_ov_has_window_list = 'ov_has_window_list'
const settings_key_ov_icons_visible = 'ov_icons_visible'
const settings_key_ov_icon_source = 'ov_icon_source'

// The built-in defaults, named once so encode can omit a field that equals its
// default and decode can fall back to it for an absent/garbage key.
const settings_default_wallpaper_color = 0
const settings_default_wallpaper_image = -1

// encode_settings serializes only the fields that differ from their built-in
// default, one `key value` per line. An all-default Settings encodes to the
// empty string. Deterministic: the same Settings always produces identical
// bytes (keys are written in a fixed order).
fn encode_settings(s Settings) string {
	mut lines := []string{}
	// preset_id: omit when it is the default preset (all-inherited look).
	if s.preset_id != default_preset_id {
		lines << '${settings_key_preset} ${s.preset_id}'
	}
	if s.wallpaper_color != settings_default_wallpaper_color {
		lines << '${settings_key_wallpaper_color} ${s.wallpaper_color}'
	}
	if s.wallpaper_image != settings_default_wallpaper_image {
		lines << '${settings_key_wallpaper_image} ${s.wallpaper_image}'
	}
	// button_side: default is .right (Windows-style).
	if s.button_side != .right {
		lines << '${settings_key_button_side} left'
	}
	// taskbar_mode: default is .standard.
	if s.taskbar_mode != .standard {
		lines << '${settings_key_taskbar_mode} combined'
	}
	// ── Per-axis overrides: written only when set (some) ───────────────
	if v := s.ov_window_radius {
		lines << '${settings_key_ov_window_radius} ${v}'
	}
	if v := s.ov_title_align {
		lines << '${settings_key_ov_title_align} ${title_align_name(v)}'
	}
	if v := s.ov_ui_size {
		lines << '${settings_key_ov_ui_size} ${v}'
	}
	if v := s.ov_title_size {
		lines << '${settings_key_ov_title_size} ${v}'
	}
	if v := s.ov_shade_enabled {
		lines << '${settings_key_ov_shade_enabled} ${bool_name(v)}'
	}
	if v := s.ov_menu_placement {
		lines << '${settings_key_ov_menu_placement} ${menu_placement_name(v)}'
	}
	if v := s.ov_title_double_click {
		lines << '${settings_key_ov_title_double_click} ${title_action_name(v)}'
	}
	if v := s.ov_has_top_bar {
		lines << '${settings_key_ov_has_top_bar} ${bool_name(v)}'
	}
	if v := s.ov_has_bottom_bar {
		lines << '${settings_key_ov_has_bottom_bar} ${bool_name(v)}'
	}
	if v := s.ov_has_window_list {
		lines << '${settings_key_ov_has_window_list} ${bool_name(v)}'
	}
	if v := s.ov_icons_visible {
		lines << '${settings_key_ov_icons_visible} ${bool_name(v)}'
	}
	if v := s.ov_icon_source {
		lines << '${settings_key_ov_icon_source} ${icon_source_name(v)}'
	}
	return lines.join('\n')
}

// decode_settings parses a blob back into Settings. Every field starts at its
// built-in default; a recognised `key value` line overrides it. Unknown keys,
// malformed lines, and out-of-range values are ignored (they leave the field at
// its default), so a truncated or garbage blob never crashes — it loads the
// defaults. An unknown preset id resolves to the default preset via the
// registry's own fallback at read time (lookandfeel_by_id), so it is kept
// verbatim here and only normalised when resolved.
fn decode_settings(blob string) Settings {
	mut s := Settings{}
	for raw in blob.split('\n') {
		line := raw.trim_space()
		if line.len == 0 {
			continue
		}
		// Split into key and the remainder (values may not contain spaces here,
		// but splitting on the first space keeps the parser tolerant).
		space := line.index(' ') or { continue }
		key := line[..space]
		value := line[space + 1..].trim_space()
		if value.len == 0 {
			continue
		}
		match key {
			settings_key_preset {
				s.preset_id = value
			}
			settings_key_wallpaper_color {
				if n := parse_settings_int(value) {
					if n >= 0 {
						s.wallpaper_color = n
					}
				}
			}
			settings_key_wallpaper_image {
				if n := parse_settings_int(value) {
					if n >= -1 {
						s.wallpaper_image = n
					}
				}
			}
			settings_key_button_side {
				s.button_side = if value == 'left' { .left } else { .right }
			}
			settings_key_taskbar_mode {
				s.taskbar_mode = if value == 'combined' { .combined } else { .standard }
			}
			settings_key_ov_window_radius {
				if n := parse_settings_int(value) {
					s.ov_window_radius = n
				}
			}
			settings_key_ov_title_align {
				if a := title_align_from(value) {
					s.ov_title_align = a
				}
			}
			settings_key_ov_ui_size {
				if n := parse_settings_int(value) {
					s.ov_ui_size = n
				}
			}
			settings_key_ov_title_size {
				if n := parse_settings_int(value) {
					s.ov_title_size = n
				}
			}
			settings_key_ov_shade_enabled {
				if b := bool_from(value) {
					s.ov_shade_enabled = b
				}
			}
			settings_key_ov_menu_placement {
				if m := menu_placement_from(value) {
					s.ov_menu_placement = m
				}
			}
			settings_key_ov_title_double_click {
				if t := title_action_from(value) {
					s.ov_title_double_click = t
				}
			}
			settings_key_ov_has_top_bar {
				if b := bool_from(value) {
					s.ov_has_top_bar = b
				}
			}
			settings_key_ov_has_bottom_bar {
				if b := bool_from(value) {
					s.ov_has_bottom_bar = b
				}
			}
			settings_key_ov_has_window_list {
				if b := bool_from(value) {
					s.ov_has_window_list = b
				}
			}
			settings_key_ov_icons_visible {
				if b := bool_from(value) {
					s.ov_icons_visible = b
				}
			}
			settings_key_ov_icon_source {
				if i := icon_source_from(value) {
					s.ov_icon_source = i
				}
			}
			else {}
		} // unknown key: ignore, the field keeps its default
	}
	return s
}

// parse_settings_int returns the integer value of `s`, or none when it is not a
// well-formed base-10 integer (with an optional leading '-'). V's string.int()
// returns 0 for garbage, which would be indistinguishable from a real 0, so a
// strict check is used to reject garbage rather than silently accept it.
fn parse_settings_int(s string) ?int {
	if s.len == 0 {
		return none
	}
	mut start := 0
	if s[0] == `-` {
		if s.len == 1 {
			return none
		}
		start = 1
	}
	for i in start .. s.len {
		if s[i] < `0` || s[i] > `9` {
			return none
		}
	}
	return s.int()
}

// Where the sparse settings blob lives. `/root` is the only writable, persistent
// part of a Vinix image (see files.v), so the desktop's preferences sit there.
const settings_file = '/root/.vinix-desktop'

// max blob size read back — the sparse settings are a handful of short lines.
const settings_blob_max = 4096

// load_settings reads and decodes the persisted settings, or returns all-default
// Settings when the file is absent/empty/garbage (never fails). Called once at
// startup so a chosen preset and overrides survive a restart.
fn load_settings() Settings {
	mut buffer := []u8{len: settings_blob_max}
	defer {
		unsafe { buffer.free() }
	}
	got := desktop_read_file(settings_file, buffer.data, u64(settings_blob_max))
	if got <= 0 {
		return Settings{} // absent or unreadable: built-in defaults
	}
	blob := buffer[..got].bytestr()
	return decode_settings(blob)
}

// save_settings encodes the desktop's current settings and writes them to the
// settings file. A sparse blob (only non-default fields) keeps "reset" as the
// simple absence of a key. Best-effort: a write failure is not fatal to the
// running session.
fn (d &Desktop) save_settings() {
	blob := encode_settings(d.settings)
	desktop_write_file(settings_file, blob.str, u64(blob.len))
}
