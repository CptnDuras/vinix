# H. Desktop surface (`DesktopSurface`)

The wallpaper plane and what sits on it. This is a **different plane** from the
shell's panels (E): panels are furniture around the edges; the desktop surface
is the backdrop and the icons on it. It is one of the **five configuration
axes** (BLUE.md canonical model).

Current state: wallpaper is already configurable (`settings.wallpaper_color` /
`wallpaper_image`, a `wallpaper_pane` in `settings_app.v`, painted by
`render.v:paint_wallpaper()`, and it crosses the app IPC boundary in
`app_process.v`) — but it lives in bare `Settings`, not in a look-and-feel axis.
Desktop icons exist only as `wm.v:shortcut_elements()` — app shortcuts hardcoded
down the left edge via `theme.v` constants, no show/hide, no arrangement.

Touches: `wallpaper.v`, `render.v` (paint), `wm.v` (`shortcut_elements`),
`theme.v` (shortcut-geometry constants), `settings.v`/`settings_app.v` (the
`DesktopSurface` axis + panes), `app_process.v` (wallpaper already crosses IPC).
Depends on: A (Configuration), B (the shared `icon_tile` renderer); H2's `files`
mode reuses the filesystem layer behind the file browser (`files.v`). Depended
on by: G (presets set a desktop surface).

**`theme.v` migration note (shared with B, ISSUES.md ISSUE-6):** the
shortcut-geometry constants migrate from `theme.v` into the `DesktopSurface`
axis; B migrates the color/measurement constants into `Decor`. Disjoint sets, no
collision.

**Icon renderer (ISSUES.md ISSUE-3):** desktop icons use B's shared `icon_tile`
renderer. The `shortcuts` mode reads `available_apps` directly and does **not**
reuse the Shell launcher's (E4) pinned-set model. Shared renderer, independent
config.

**Wallpaper as an axis (ISSUES.md ISSUE-5):** wallpaper fields move from bare
`Settings` into the `DesktopSurface` axis so a preset can ship a backdrop. The
existing `app_process.v` IPC encoding of `wallpaper_color`/`wallpaper_image`
must keep working — the resolver produces the same two values it sends today.

## Sub-features

1. **Wallpaper.** Fold the existing wallpaper configuration into the resolvable
   `DesktopSurface` axis, so a preset can ship a backdrop while the user
   override still works. Keeps the color/image picker. *Deep pass defines:
   moving wallpaper fields into resolved config without breaking the IPC
   encoding, scaling/fit options, preset-vs-override interaction.*
   - **Acceptance criteria:** (a) resolved wallpaper reproduces today's paint
     for the same color/image selection; (b) a preset-supplied wallpaper shows
     when the user has no override; (c) a user override wins over the preset;
     (d) the `app_process.v` IPC still transmits the effective color/image
     unchanged.
   - **Testing:** assert `paint_wallpaper()` uses the resolved values; a test
     that override beats preset beats default for the wallpaper fields; assert
     the IPC-encoded ints equal the resolved selection (guards the boundary).

2. **Desktop-icon content *(configurable: either mode)*.** `icon_source ∈
   {shortcuts, files}`. `shortcuts` = app launchers (reuses `available_apps`);
   `files` = real files/folders in a desktop directory, enumerated and
   change-watched (reuse `files.v` / inotify). `shortcuts` ships first; `files`
   is the heavier, later sub-feature. Both feed one icon model rendered by B's
   `icon_tile`. *Deep pass defines: the `icon_source` config, the two content
   providers behind one model, the `files` mode enumeration/watch/open.*
   - **Acceptance criteria:** (a) `shortcuts` renders one `icon_tile` per
     app as today's left-edge shortcuts do; (b) switching to `files` lists the
     desktop directory's entries as tiles (folders first, like `files.v`); (c)
     both modes share the `icon_tile` renderer; (d) `files` mode reflects a
     directory change after a watch event.
   - **Testing:** `shortcuts` mode asserts one tile per `available_apps` entry
     with today's ids; `files` mode over a temp dir asserts a tile per entry and
     folders-first ordering; a watch test that adding a file adds a tile.

3. **Desktop-icon visibility & arrangement.** Show/hide toggle; turn the
   hardcoded left-edge layout into config: edge/free placement, grid vs list,
   spacing, label style. *Deep pass defines: the arrangement model, the
   `shortcut_elements()` refactor to read it, the show/hide path.*
   - **Acceptance criteria:** (a) hidden = no icon elements emitted; (b) the
     default arrangement reproduces today's left-edge column exactly; (c)
     changing edge/spacing repositions tiles by rule.
   - **Testing:** assert hidden yields zero icon children; golden test that the
     default arrangement matches today's `shortcut_elements()` geometry; a
     layout test for an alternate edge/spacing.

4. **Desktop context menu *(deferred)*.** Right-click the desktop → change
   wallpaper / arrange icons / show-hide icons. Uses F's menu model. *Deep pass
   defines: menu content and trigger, once F exists.*
   - **Acceptance criteria (deferred):** (a) right-click on empty desktop opens
     the context menu; (b) its actions change the corresponding `DesktopSurface`
     settings; (c) it uses F's `Menu` type (no bespoke menu).
   - **Testing (deferred):** assert the context menu action ids map to
     DesktopSurface setting mutations.

## Open questions

- Which desktop directory backs `files` mode (`~/Desktop`?), created on demand?
- Icon content mixing (shortcuts *and* files) vs single-choice. *(Decided:
  single-choice axis for the first cut.)*
- Shared `icon_tile` with the launcher: *(decided — shared renderer, independent
  hosts, ISSUES.md ISSUE-3).*
