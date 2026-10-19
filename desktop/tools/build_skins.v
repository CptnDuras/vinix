// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Assembles the installed window skins: desktop/skins/<id>/ -> <out>/<id>/ plus
// <out>/index.txt, one "<id> <name>" line per skin. The desktop reads PNG, SVG,
// path-text (.vec) and VBM1 (.vbm) art as it is, so this only copies the files a
// skin may name and lists the skins. See desktop/skins/README.md.
//
// Usage: build_skins <skins-dir> <output-dir>
module main

import os

// A skin's id is a directory name, and its files are plain names, as the
// desktop's loader requires (skin_id_valid, skin_file_name_valid).
fn id_valid(id string) bool {
	if id.len == 0 || id.len > 32 {
		return false
	}
	return id.bytes().all((it >= `a` && it <= `z`) || (it >= `0` && it <= `9`) || it == `-` || it == `_`)
}

fn art_file(name string) bool {
	if name.len == 0 || name.len > 64 || name[0] == `.` {
		return false
	}
	if !name.bytes().all((it >= `a` && it <= `z`) || (it >= `0` && it <= `9`) || it == `-`
		|| it == `_` || it == `.`) {
		return false
	}
	return name.ends_with('.png') || name.ends_with('.svg') || name.ends_with('.vec')
		|| name.ends_with('.vbm')
}

fn skin_name(cfg string, id string) string {
	for line in cfg.split_into_lines() {
		if line.starts_with('name=') {
			return line[5..].trim_space()
		}
	}
	return id
}

fn main() {
	if os.args.len != 3 {
		eprintln('usage: build_skins <skins-dir> <output-dir>')
		exit(2)
	}
	source := os.args[1]
	out := os.args[2]
	os.mkdir_all(out) or {
		eprintln('cannot create ${out}: ${err}')
		exit(1)
	}
	mut ids := os.ls(source) or {
		eprintln('cannot read ${source}: ${err}')
		exit(1)
	}
	ids.sort()
	mut index := []string{}
	for id in ids {
		dir := os.join_path(source, id)
		cfg_path := os.join_path(dir, 'skin.cfg')
		if !id_valid(id) || !os.is_dir(dir) || !os.is_file(cfg_path) {
			continue
		}
		cfg := os.read_file(cfg_path) or {
			eprintln('skin ${id}: ${err}')
			exit(1)
		}
		dest := os.join_path(out, id)
		os.mkdir_all(dest) or {
			eprintln('cannot create ${dest}: ${err}')
			exit(1)
		}
		os.write_file(os.join_path(dest, 'skin.cfg'), cfg) or {
			eprintln('skin ${id}: ${err}')
			exit(1)
		}
		for file in os.ls(dir) or { []string{} } {
			if art_file(file) {
				os.cp(os.join_path(dir, file), os.join_path(dest, file)) or {
					eprintln('skin ${id}: ${file}: ${err}')
					exit(1)
				}
			}
		}
		index << '${id} ${skin_name(cfg, id)}'
	}
	os.write_file(os.join_path(out, 'index.txt'), index.join('\n') + if index.len > 0 { '\n' } else { '' }) or {
		eprintln('cannot write the index: ${err}')
		exit(1)
	}
}
