// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// The skin Theme Studio is putting together: which picture is each control's,
// and what plate sits under it. Pure, so it is tested without a window. The
// skin.cfg it writes is the format skins/README.md describes, and is checked by
// reading it back with the desktop's own parser.
module main

// The controls the studio edits, by the names skin.cfg gives them.
const studio_widget_names = ['close', 'minimize', 'maximize', 'shade', 'menu']!

// What sits under a control's picture.
enum StudioPlate {
	none_
	grey
	shaded
}

// The plates' skin.cfg text: Windows 3.1's grey box and Platinum's shaded one.
fn studio_plate_cfg(plate StudioPlate) string {
	return match plate {
		.none_ { '' }
		.grey { 'bevel:#c0c0c0:#ffffff:#808080:#000000' }
		.shaded { 'bevel:#eeeeee:#ffffff:#8c8c8c:#2b2b2b:#c2c2c2' }
	}
}

struct StudioWidget {
mut:
	// The PNG in the skin's folder, or empty for the look's own face.
	file string
	// The picture's side, which sets the control's.
	art int
}

struct StudioSkin {
mut:
	id      string
	name    string
	plate   StudioPlate
	widgets [5]StudioWidget
}

// studio_widget_file is the file a control's picture is kept in.
fn studio_widget_file(index int) string {
	return '${studio_widget_names[index]}.png'
}

// studio_control_size is the side a control is drawn at: the picture one to
// one, or twice over when a plate surrounds it (the desktop draws the picture
// in the middle half).
fn studio_control_size(art int, plate StudioPlate) int {
	side := if plate == .none_ { art } else { art * 2 }
	return clamp_int(side, 6, 64)
}

// cfg is the skin.cfg for this skin.
fn (s &StudioSkin) cfg() string {
	mut out := 'name=${if s.name.len > 0 { s.name } else { s.id }}\n'
	for index, widget in s.widgets {
		if widget.file.len == 0 {
			continue
		}
		name := studio_widget_names[index]
		out += 'widget.${name}=bitmap:${widget.file}\n'
		if s.plate != .none_ {
			out += 'widget.${name}.plate=${studio_plate_cfg(s.plate)}\n'
		}
		out += 'widget.${name}.size=${studio_control_size(widget.art, s.plate)}\n'
	}
	return out
}

// studio_skin_from_cfg reads a skin.cfg back into the editor's form. Only what
// the editor makes survives: a control's bitmap, and a plate that is one of the
// two it offers.
fn studio_skin_from_cfg(id string, text string) StudioSkin {
	parsed := parse_skin(id, '', text)
	mut out := StudioSkin{
		id: id
		name: parsed.name
	}
	for index, name in studio_widget_names {
		widget := parsed.widgets[name] or { continue }
		if widget.normal.kind == .bitmap {
			out.widgets[index] = StudioWidget{
				file: widget.normal.file
				art: if widget.size > 0 { widget.size } else { 0 }
			}
		}
		if widget.plate.kind == .bevel {
			out.plate = if widget.plate.face2 != 0 { StudioPlate.shaded } else { StudioPlate.grey }
			if out.widgets[index].art > 0 {
				out.widgets[index].art = out.widgets[index].art / 2
			}
		}
	}
	return out
}
