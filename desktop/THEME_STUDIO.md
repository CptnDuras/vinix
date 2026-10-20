# Theme Studio

Theme Studio (`vinix-theme-studio`) is a pixel editor in the manner of the
original Paint, and a page that turns the pictures into a window-control skin
(see [skins/README.md](skins/README.md)). It is in the Start menu and on the
desktop, and opens a 780 by 640 window.

Both tabs work on one skin folder, named in the **Skin folder** box at the top
right. It is a folder of the user's own skins, `/root/.vinix-skins/<name>/`
(`VINIX_USER_SKIN_DIR` moves the parent), and the name may use `a-z`, `0-9`, `-`
and `_`.

## Paint

* **Tools**: Pencil, Eraser, Fill, Picker, Line, Box and Filled box, Oval and
  Filled oval. Shapes follow the pointer while it is down and are drawn when it
  is let go. The Picker takes the colour under the pointer and returns to the
  Pencil, as Paint's does. The Eraser, and the last swatch of the palette, make
  transparent pixels, which is what the edge of a control wants.
* **Brush** is the width of the Pencil, Eraser and Line, one to four pixels.
* **Palette** is Paint's twenty-eight colours; **Colour** takes any `#rrggbb`
  (or `none`) and **Set** (or Enter) uses it.
* **Picture size** is 10, 16, 24, 32 or 48 pixels square; a picture can be up to
  64. Changing it keeps the top left of what is drawn.
* **Undo** and **Redo** (also Ctrl+Z and Ctrl+Y) take back up to forty steps;
  **Clear picture** is one of them. **Grid** shows the pixel boundaries.
* **File name**, **Save** and **Open** write and read `<name>.png` in the skin
  folder: an ordinary 8-bit RGBA PNG, which is what a skin's `bitmap:` names.

## Skin

* **Plate under each control** is *None*, *Grey bevel* (Windows 3.1's boxes) or
  *Shaded bevel* (Platinum's). A plate makes each control twice the side of its
  picture, with the picture in the middle half.
* For each of Close, Minimise, Zoom, Roll up and Menu, **Use drawing** saves what
  is on the Paint tab as that control's picture (`close.png`, `minimize.png`,
  `maximize.png`, `shade.png`, `menu.png`) and shows it as the desktop will draw
  it. **Edit** brings it back into the editor and **Remove** takes it off.
* **Save skin** writes `skin.cfg`. **Open skin** reads the folder's `skin.cfg`
  back. Then choose the skin in Settings, Appearance, Skins; the page reads the
  folders again when it is opened.

A skin made here has the controls' pictures and their plates. The bar behind the
title, the controls' hover and pressed faces and the frame are not in the studio;
a `skin.cfg` written by hand can carry them, and the studio keeps nothing of
them when it saves.

## Files

| File | What |
| --- | --- |
| `paint_model.v` | the picture, the tools and undo; plain arithmetic, tested alone |
| `paint_png.v` | PNG reading and writing, with alpha |
| `studio_skin.v` | the skin being made, and its `skin.cfg` |
| `studio_app.v` | the window: pointer, keyboard, files and the two pages |

Tests: `paint_model_test.v` and `studio_skin_test.v` run with
`tools/test-blue.sh`; `tools/tests/studio_app_test.v` drives the window.
