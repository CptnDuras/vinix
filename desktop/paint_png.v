// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Reading and writing the pixel editor's pictures as PNG files, which is what a
// skin's `bitmap:` names. Writing keeps Capture's approach: a standard PNG whose
// DEFLATE blocks are stored rather than compressed, so no compression runtime
// is needed and a skin-sized picture stays small anyway. Unlike Capture's it
// carries alpha.
module main

// paint_png_bytes is the picture as a PNG file: eight bits of red, green, blue
// and alpha per pixel.
fn paint_png_bytes(d &PaintDoc) []u8 {
	row_size := d.width * 4 + 1
	mut raw := []u8{len: row_size * d.height}
	for y in 0 .. d.height {
		row := y * row_size
		raw[row] = 0 // filter: none
		for x in 0 .. d.width {
			pixel := d.pixels[y * d.width + x]
			offset := row + 1 + x * 4
			raw[offset] = u8(pixel >> 16)
			raw[offset + 1] = u8(pixel >> 8)
			raw[offset + 2] = u8(pixel)
			raw[offset + 3] = u8(pixel >> 24)
		}
	}
	blocks := (raw.len + 65534) / 65535
	mut compressed := []u8{cap: raw.len + blocks * 5 + 6}
	compressed << u8(0x78)
	compressed << u8(0x01)
	mut offset := 0
	for offset < raw.len {
		remaining := raw.len - offset
		length := if remaining > 65535 { 65535 } else { remaining }
		compressed << if offset + length == raw.len { u8(1) } else { u8(0) }
		capture_put_le16(mut compressed, u16(length))
		capture_put_le16(mut compressed, ~u16(length))
		compressed << raw[offset..offset + length]
		offset += length
	}
	capture_put_be32(mut compressed, capture_adler32(raw))

	mut ihdr := []u8{cap: 13}
	capture_put_be32(mut ihdr, u32(d.width))
	capture_put_be32(mut ihdr, u32(d.height))
	ihdr << u8(8) // bit depth
	ihdr << u8(6) // truecolour with alpha
	ihdr << u8(0) // compression
	ihdr << u8(0) // filter
	ihdr << u8(0) // no interlace

	mut png := []u8{cap: 8 + 25 + compressed.len + 24}
	for byte in [u8(0x89), `P`, `N`, `G`, `\r`, `\n`, 0x1a, `\n`]! {
		png << byte
	}
	capture_png_chunk(mut png, 'IHDR', ihdr)
	capture_png_chunk(mut png, 'IDAT', compressed)
	capture_png_chunk(mut png, 'IEND', []u8{})
	return png
}

// paint_doc_from_png reads a PNG a skin could use into a picture, if it is one
// the editor can hold.
fn paint_doc_from_png(data []u8) ?PaintDoc {
	bitmap := decode_skin_png(data) or { return none }
	if bitmap.width > paint_max_side || bitmap.height > paint_max_side {
		return none
	}
	return PaintDoc{
		width: bitmap.width
		height: bitmap.height
		pixels: bitmap.pixels.clone()
	}
}

// paint_save_png writes the picture to a file, and says whether that worked.
fn paint_save_png(path string, d &PaintDoc) bool {
	bytes := paint_png_bytes(d)
	ok := desktop_write_file(path, bytes.data, u64(bytes.len))
	unsafe { bytes.free() }
	return ok
}

// paint_load_png reads a picture from a file.
fn paint_load_png(path string) ?PaintDoc {
	info := desktop_stat(path) or { return none }
	if info.is_dir || info.size == 0 || info.size > u64(skin_asset_max) {
		return none
	}
	mut buffer := []u8{len: int(info.size)}
	got := desktop_read_file(path, buffer.data, info.size)
	if got != i64(info.size) {
		return none
	}
	return paint_doc_from_png(buffer)
}
