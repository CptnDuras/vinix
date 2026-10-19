// Copyright (c) 2026 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL v2 license
// that can be found in the LICENSE file.

// SPDX-License-Identifier: GPL-2.0-or-later
// One versioned record for every desktop preference. No device readback,
// pending request, or application-local state belongs in this file.
module main

const desktop_preferences_name = '.vinix-desktop-settings'
const desktop_preferences_max_bytes = 4096
const desktop_legacy_scale_name = '.vinix-desktop-scale'

struct DesktopPreferences {
mut:
	settings Settings
	// Zero keeps geometry-based selection. Saving a theme or wallpaper must
	// not turn an automatic scale into a permanent display override.
	scale int
}

fn (p DesktopPreferences) configure_scale(width int, height int) int {
	fallback := desktop_configure_scale(width, height)
	if !desktop_scale_valid(p.scale) {
		return fallback
	}
	desktop_request_scale(p.scale)
	desktop_commit_scale(p.scale)
	return p.scale
}

// A preset id is one word in the preferences file, so it can hold neither
// whitespace nor a line break.
fn desktop_preset_id_valid(id string) bool {
	if id.len == 0 || id.len > 32 {
		return false
	}
	for ch in id {
		if !(ch.is_letter() || ch.is_digit() || ch == `_` || ch == `-`) {
			return false
		}
	}
	return true
}

// The per-axis overrides a user has set (Blue spec A3/G3). A key is written
// only while its override is set, and an absent key inherits the preset.
const desktop_override_keys = ['ov_window_radius', 'ov_title_align', 'ov_ui_size', 'ov_title_size',
	'ov_shade_enabled', 'ov_menu_placement', 'ov_title_double_click', 'ov_has_top_bar',
	'ov_has_bottom_bar', 'ov_has_window_list', 'ov_icons_visible', 'ov_icon_source', 'ov_title_kind', 'ov_tab_align',
	'ov_widgets', 'ov_title_middle_click', 'ov_tab_width']

// The duplicate-detection bit of an override key, after the fixed keys' bits;
// zero for a key that is not an override.
fn desktop_override_bit(key string) u64 {
	for index, name in desktop_override_keys {
		if name == key {
			return u64(1) << (21 + u64(index))
		}
	}
	return 0
}

// desktop_parse_override applies one override line; none for a bad value.
fn desktop_parse_override(mut s Settings, key string, value string) ?bool {
	match key {
		'ov_window_radius' { s.ov_window_radius = desktop_preference_index(value)? }
		'ov_title_align' { s.ov_title_align = title_align_from(value)? }
		'ov_ui_size' { s.ov_ui_size = desktop_preference_index(value)? }
		'ov_title_size' { s.ov_title_size = desktop_preference_index(value)? }
		'ov_shade_enabled' { s.ov_shade_enabled = bool_from(value)? }
		'ov_menu_placement' { s.ov_menu_placement = menu_placement_from(value)? }
		'ov_title_double_click' { s.ov_title_double_click = title_action_from(value)? }
		'ov_title_middle_click' { s.ov_title_middle_click = title_action_from(value)? }
		'ov_tab_width' {
			width := desktop_preference_index(value)?
			if width != 0 && (width < 10 || width > 100) {
				return none
			}
			s.ov_tab_width = width
		}
		'ov_has_top_bar' { s.ov_has_top_bar = bool_from(value)? }
		'ov_has_bottom_bar' { s.ov_has_bottom_bar = bool_from(value)? }
		'ov_has_window_list' { s.ov_has_window_list = bool_from(value)? }
		'ov_icons_visible' { s.ov_icons_visible = bool_from(value)? }
		'ov_icon_source' { s.ov_icon_source = icon_source_from(value)? }
		'ov_title_kind' { s.ov_title_kind = title_kind_from(value)? }
		'ov_tab_align' { s.ov_tab_align = title_align_from(value)? }
		'ov_widgets' {
			list := widgets_from_text(value)?
			s.ov_widgets = int(widgets_pack(list))
		}
		else {}
	}
	return true
}

// desktop_encode_overrides writes the overrides that are set, one per line.
fn desktop_encode_overrides(s Settings) string {
	mut out := ''
	if v := s.ov_window_radius {
		out += 'ov_window_radius=${v}\n'
	}
	if v := s.ov_title_align {
		out += 'ov_title_align=${title_align_name(v)}\n'
	}
	if v := s.ov_ui_size {
		out += 'ov_ui_size=${v}\n'
	}
	if v := s.ov_title_size {
		out += 'ov_title_size=${v}\n'
	}
	if v := s.ov_shade_enabled {
		out += 'ov_shade_enabled=${bool_name(v)}\n'
	}
	if v := s.ov_menu_placement {
		out += 'ov_menu_placement=${menu_placement_name(v)}\n'
	}
	if v := s.ov_title_double_click {
		out += 'ov_title_double_click=${title_action_name(v)}\n'
	}
	if v := s.ov_title_middle_click {
		out += 'ov_title_middle_click=${title_action_name(v)}\n'
	}
	if v := s.ov_tab_width {
		out += 'ov_tab_width=${v}\n'
	}
	if v := s.ov_has_top_bar {
		out += 'ov_has_top_bar=${bool_name(v)}\n'
	}
	if v := s.ov_has_bottom_bar {
		out += 'ov_has_bottom_bar=${bool_name(v)}\n'
	}
	if v := s.ov_has_window_list {
		out += 'ov_has_window_list=${bool_name(v)}\n'
	}
	if v := s.ov_icons_visible {
		out += 'ov_icons_visible=${bool_name(v)}\n'
	}
	if v := s.ov_icon_source {
		out += 'ov_icon_source=${icon_source_name(v)}\n'
	}
	if v := s.ov_title_kind {
		out += 'ov_title_kind=${title_kind_name(v)}\n'
	}
	if v := s.ov_tab_align {
		out += 'ov_tab_align=${title_align_name(v)}\n'
	}
	if v := s.ov_widgets {
		out += 'ov_widgets=${widgets_to_text(widgets_unpack(u32(v)))}\n'
	}
	if s.skin_id.len > 0 {
		out += 'skin=${s.skin_id}\n'
	}
	return out
}

fn desktop_preferences_valid(p DesktopPreferences) bool {
	return (p.scale == 0 || desktop_scale_valid(p.scale))
		&& int(p.settings.button_side) >= int(ButtonSide.right)
		&& int(p.settings.button_side) <= int(ButtonSide.left)
		&& int(p.settings.taskbar_mode) >= int(TaskbarMode.standard)
		&& int(p.settings.taskbar_mode) <= int(TaskbarMode.combined)
		&& desktop_preset_id_valid(p.settings.preset_id)
		&& p.settings.glass_color >= 0 && p.settings.glass_color < glass_colors.len
		&& (p.settings.skin_id.len == 0 || p.settings.skin_id == 'none'
		|| skin_id_valid(p.settings.skin_id))
		&& (p.settings.ov_widgets or { 0 }) >= 0 && (p.settings.ov_widgets or { 0 }) <= 0x0fffffff
		&& (p.settings.ov_window_radius or { 0 }) >= 0 && (p.settings.ov_window_radius or { 0 }) <= 64
		&& (p.settings.ov_ui_size or { 8 }) >= 8 && (p.settings.ov_ui_size or { 8 }) <= 96
		&& (p.settings.ov_title_size or { 8 }) >= 8 && (p.settings.ov_title_size or { 8 }) <= 96
		&& int(p.settings.language) >= 0 && int(p.settings.language) < desktop_languages.len
		&& p.settings.wallpaper_color >= 0
		&& p.settings.wallpaper_color < wallpaper_colors.len
		&& p.settings.wallpaper_image >= -1
		&& keyboard_settings_valid(p.settings.keyboard_layouts, p.settings.keyboard_layout)
		&& idle_timeouts_valid(p.settings.display_off_minutes, p.settings.sleep_minutes)
		&& int(p.settings.lid_action) >= int(LidAction.suspend)
		&& int(p.settings.lid_action) <= int(LidAction.ignore)
		&& int(p.settings.power_profile) >= int(PowerProfile.automatic)
		&& int(p.settings.power_profile) <= int(PowerProfile.power_saver)
}

// An idle timeout is saved as its minutes, or `never`.
fn desktop_encode_idle_timeout(minutes int) string {
	return if minutes == 0 { 'never' } else { minutes.str() }
}

// Only the timeouts Settings offers: a number it does not is not rounded to
// one that it does.
fn desktop_parse_idle_timeout(text string) ?int {
	if text == 'never' {
		return 0
	}
	minutes := desktop_preference_index(text)?
	if minutes <= 0 || !idle_timeout_offered(minutes) {
		return none
	}
	return minutes
}

// The enabled input sources are saved in Settings' order, e.g. `us,ru`.
fn desktop_encode_keyboard_layouts(mask u32) string {
	mut codes := []string{cap: keyboard_layouts.len}
	for layout in keyboard_layouts {
		if mask & layout.bit() != 0 {
			codes << layout.code()
		}
	}
	text := codes.join(',')
	unsafe { codes.free() }
	return text
}

// Each code once, at least one, nothing unknown; the slices are borrowed.
fn desktop_parse_keyboard_layouts(text string) ?u32 {
	mut mask := u32(0)
	mut start := 0
	for start <= text.len {
		mut end := start
		for end < text.len && text[end] != `,` {
			end++
		}
		layout := keyboard_layout_from_code(text[start..end]) or { return none }
		if mask & layout.bit() != 0 {
			return none
		}
		mask |= layout.bit()
		start = end + 1
	}
	return mask
}

fn desktop_encode_preferences(p DesktopPreferences) ?string {
	if !desktop_preferences_valid(p) {
		return none
	}
	scale := match p.scale {
		0 { 'auto' }
		desktop_scale_100 { '1' }
		else { '2' }
	}
	side := if p.settings.button_side == .left { 'left' } else { 'right' }
	taskbar := if p.settings.taskbar_mode == .combined { 'combined' } else { 'standard' }
	show_overview := if p.settings.taskbar_show_overview { 'true' } else { 'false' }
	show_workspaces := if p.settings.taskbar_show_workspaces { 'true' } else { 'false' }
	theme := p.settings.preset_id
	language := p.settings.language.code()
	clock_24_hour := if p.settings.clock_24_hour { 'true' } else { 'false' }
	clock_show_seconds := if p.settings.clock_show_seconds { 'true' } else { 'false' }
	clock_show_date := if p.settings.clock_show_date { 'true' } else { 'false' }
	clock_show_weekday := if p.settings.clock_show_weekday { 'true' } else { 'false' }
	keyboard_sources := desktop_encode_keyboard_layouts(p.settings.keyboard_layouts)
	keyboard_layout := p.settings.keyboard_layout.code()
	display_off := desktop_encode_idle_timeout(p.settings.display_off_minutes)
	sleep := desktop_encode_idle_timeout(p.settings.sleep_minutes)
	lid_action := p.settings.lid_action.code()
	power_profile := p.settings.power_profile.code()
	record := 'version=1\nscale=${scale}\nbutton_side=${side}\ntaskbar_mode=${taskbar}\ntaskbar_show_overview=${show_overview}\ntaskbar_show_workspaces=${show_workspaces}\ntheme=${theme}\nglass_color=${p.settings.glass_color}\nlanguage=${language}\nclock_24_hour=${clock_24_hour}\nclock_show_seconds=${clock_show_seconds}\nclock_show_date=${clock_show_date}\nclock_show_weekday=${clock_show_weekday}\nwallpaper_color=${p.settings.wallpaper_color}\nwallpaper_image=${p.settings.wallpaper_image}\nkeyboard_layouts=${keyboard_sources}\nkeyboard_layout=${keyboard_layout}\ndisplay_off_after=${display_off}\nsleep_after=${sleep}\nlid_action=${lid_action}\npower_profile=${power_profile}\n${desktop_encode_overrides(p.settings)}'
	unsafe {
		display_off.free()
		sleep.free()
	}
	return record
}

// Unlike string.int(), this cannot accept a numeric prefix or wrap on overflow.
fn desktop_preference_index(text string) ?int {
	if text == '-1' {
		return -1
	}
	if text.len == 0 || text.len > 10 {
		return none
	}
	mut value := 0
	for byte in text {
		if byte < `0` || byte > `9` {
			return none
		}
		digit := int(byte - `0`)
		if value > (2147483647 - digit) / 10 {
			return none
		}
		value = value * 10 + digit
	}
	return value
}

// Parse borrowed slices, not a tree of allocated strings: the desktop uses
// -manualfree. Missing keys keep defaults; unknown keys allow schema extension.
// Reject malformed or duplicate known fields as a whole, never partially apply
// a damaged snapshot. A version is mandatory, including for an otherwise empty
// record. File loading is separately bounded and rejects non-regular files.
fn desktop_parse_preferences(record string) ?DesktopPreferences {
	if record.len == 0 || record.len > desktop_preferences_max_bytes
		|| record.index_u8(0) >= 0 {
		return none
	}
	mut p := DesktopPreferences{}
	mut seen := u64(0)
	mut start := 0
	for start < record.len {
		mut end := start
		for end < record.len && record[end] != `\n` {
			end++
		}
		line := record[start..end].trim_space()
		start = end + 1
		if line.len == 0 || line.starts_with('#') {
			continue
		}
		equals := line.index_u8(`=`)
		if equals <= 0 {
			return none
		}
		key := line[..equals].trim_space()
		value := line[equals + 1..].trim_space()
		bit := match key {
			'version' { u64(1) }
			'scale' { u64(2) }
			'button_side' { u64(4) }
			'taskbar_mode' { u64(8) }
			'theme' { u64(16) }
			'wallpaper_color' { u64(32) }
			'wallpaper_image' { u64(64) }
			'clock_24_hour' { u64(128) }
			'clock_show_seconds' { u64(256) }
			'clock_show_date' { u64(512) }
			'clock_show_weekday' { u64(1024) }
			'keyboard_layouts' { u64(2048) }
			'keyboard_layout' { u64(4096) }
			'language' { u64(8192) }
			'display_off_after' { u64(16384) }
			'sleep_after' { u64(32768) }
			'lid_action' { u64(65536) }
			'power_profile' { u64(131072) }
			'glass_color' { u64(262144) }
			'taskbar_show_overview' { u64(524288) }
			'taskbar_show_workspaces' { u64(1048576) }
			'skin' { u64(1) << 40 }
			else { desktop_override_bit(key) }
		}
		if seen & bit != 0 {
			return none
		}
		seen |= bit
		match key {
			'version' {
				if value != '1' { return none }
			}
			'scale' {
				p.scale = match value {
					'auto' { 0 }
					'1' { desktop_scale_100 }
					'2' { desktop_scale_200 }
					else { return none }
				}
			}
			'button_side' {
				p.settings.button_side = match value {
					'right' { ButtonSide.right }
					'left' { ButtonSide.left }
					else { return none }
				}
			}
			'taskbar_mode' {
				p.settings.taskbar_mode = match value {
					'standard' { TaskbarMode.standard }
					'combined' { TaskbarMode.combined }
					else { return none }
				}
			}
			'taskbar_show_overview' {
				p.settings.taskbar_show_overview = match value {
					'true' { true }
					'false' { false }
					else { return none }
				}
			}
			'taskbar_show_workspaces' {
				p.settings.taskbar_show_workspaces = match value {
					'true' { true }
					'false' { false }
					else { return none }
				}
			}
			'theme' {
				// Older files name only 'default' or 'macos'; every preset id is
				// kept in the same key, so those read back unchanged.
				if !desktop_preset_id_valid(value) {
					return none
				}
				p.settings.preset_id = value
			}
			'language' {
				p.settings.language = desktop_language_from_code(value)?
			}
			'skin' {
				if value != 'none' && !skin_id_valid(value) {
					return none
				}
				p.settings.skin_id = value
			}
			'clock_24_hour' {
				p.settings.clock_24_hour = match value {
					'true' { true }
					'false' { false }
					else { return none }
				}
			}
			'clock_show_seconds' {
				p.settings.clock_show_seconds = match value {
					'true' { true }
					'false' { false }
					else { return none }
				}
			}
			'clock_show_date' {
				p.settings.clock_show_date = match value {
					'true' { true }
					'false' { false }
					else { return none }
				}
			}
			'clock_show_weekday' {
				p.settings.clock_show_weekday = match value {
					'true' { true }
					'false' { false }
					else { return none }
				}
			}
			'glass_color' { p.settings.glass_color = desktop_preference_index(value)? }
			'wallpaper_color' { p.settings.wallpaper_color = desktop_preference_index(value)? }
			'wallpaper_image' { p.settings.wallpaper_image = desktop_preference_index(value)? }
			'keyboard_layouts' { p.settings.keyboard_layouts = desktop_parse_keyboard_layouts(value)? }
			'keyboard_layout' { p.settings.keyboard_layout = keyboard_layout_from_code(value)? }
			'display_off_after' { p.settings.display_off_minutes = desktop_parse_idle_timeout(value)? }
			'sleep_after' { p.settings.sleep_minutes = desktop_parse_idle_timeout(value)? }
			'lid_action' { p.settings.lid_action = lid_action_from_code(value)? }
			'power_profile' { p.settings.power_profile = power_profile_from_code(value)? }
			else {
				if bit != 0 {
					desktop_parse_override(mut p.settings, key, value)?
				}
			}
		}
	}
	// A record naming only the current input source enables it beside US, and
	// one listing only the enabled sources types with the first of them. When
	// both are named the current one must be among the enabled.
	if seen & u64(2048) == 0 {
		p.settings.keyboard_layouts |= p.settings.keyboard_layout.bit()
	} else if seen & u64(4096) == 0 {
		p.settings.keyboard_layout = keyboard_first_layout(p.settings.keyboard_layouts)
	}
	// A record naming one idle timeout has never beside it, which holds with
	// any time. When both are named they must already agree, as validation
	// checks.
	if seen & u64(1) == 0 || !desktop_preferences_valid(p) {
		return none
	}
	return p
}
