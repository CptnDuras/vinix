# Blue — a look-and-feel system for the Vinix desktop

Blue is a configurable look-and-feel layer for the native Vinix desktop
(`vinix-desktop`). It is named after Apple's *Blue* — the pragmatic, shipping
sibling of the *Pink*/Taligent next-generation Mac effort — and it takes its
design values from the era its name evokes: BeOS, Mac OS Platinum, and Windows
2000. The goal is not museum reproduction. It is to recover a *lost design
virtue* — restrained near-neutral palettes, legible structural depth (raised
buttons, sunken fields, grooved dividers), and chrome that stays out of the way
of work — and render it with modern quality (anti-aliased type, soft shadows,
subtle rounding).

Blue ships as the flagship preset of a general system. That system is the real
deliverable: a **look-and-feel registry** of overridable presets that control
five axes — **decorations, typography, window handling, the shell, and the
desktop surface** — plus a cross-cutting **menu system**. A user composes their
environment by picking a preset and, where they wish, overriding individual
axes. Windows, classic Mac, and BeOS arrangements are all expressible as
configuration, not code paths.

Nothing here changes the Vinix kernel or the Linux-compatibility userland —
Blue lives entirely in `desktop/`.

---

## This document

This is the **Tier-1 high-level map**. It states the design principles and
indexes the major features. Each major feature has its own **Tier-2 document**
under [`blue-specs/`](blue-specs/), and inside each Tier-2 document is a
**numerated list of the small features** that compose it (Tier 3). Deep,
implementation-ready detail is written into those numbered sections during the
depth pass.

Spec process: **wide first** (this map + the Tier-2 docs with their numerated
sub-feature lists), **then deep** (expand each numbered item), **then a
reconciliation pass** for agreement and tight scope across all specs. No
implementation code is written until the specs are agreed.

---

## Canonical model (authoritative)

The system has exactly **five configurable axes** and **two cross-cutting
concerns**. This enumeration is authoritative; every Tier-2 doc conforms to it.

**Axes** (each is an optional field on `LookAndFeel` and on `Settings`, resolved
by A):
- `Decor` (B) — window/chrome visual theme
- `Typography` (C) — fonts, sizes, weights, smoothing
- `Behavior` (D) — window handling policy, incl. `menu_placement`
- `Shell` (E) — panels and their items
- `DesktopSurface` (H) — wallpaper, desktop icons

**Cross-cutting concerns** (not axes):
- Configuration (A) — the meta-model and resolver every axis flows through
- Menu system (F) — a `Menu` data type + hosts; its only user knob is
  `Behavior.menu_placement` (an axis field), so it owns no axis of its own

Dependency direction (acyclic): `A → {B, C, D, E, H}`; `B → E`; `E → D2`
(maximize respects panels); `{A, B, D, E} → F`; `{A…H} → G`. E exposes a generic
`app_menu` slot typed on F's `Menu`; F targets that slot. This breaks the former
E↔F cycle (see ISSUES.md ISSUE-2). Note the only edge touching F is `F → E`, and
`E → D2` is a one-way layout query, so the graph remains acyclic.

---

## Design principles

1. **Restraint is the palette.** A coherent neutral gray ramp with a single
   reserved accent. Color carries meaning (focus, selection, alert) precisely
   because almost nothing else is colored.
2. **Depth is structure, not decoration.** A raised edge means "pressable," a
   sunken edge means "type here," a groove means "divider." The interface is
   parsed structurally, at a glance, without reading.
3. **Period structure, modern rendering.** The bevel/palette/spacing grammar of
   1998; the type, smoothing, and soft shadows of today.
4. **The shell is composable, not modal.** "Has a taskbar," "has a top bar,"
   "shows a global menu," "shows a window list" are independent settings.
   Windows / Mac / BeOS are presets that place the same items into zero, one,
   or two bars.
5. **Everything is overridable, and "not set" is valid.** Configuration is a
   three-state resolution, never a hardcoded look.
6. **Build on top of Vinix.** New behavior lives in new files; existing files
   are touched only at unavoidable seams, and preferably reduced to delegating
   into Blue's code, so the fork tracks upstream cleanly.

---

## Major feature map

Each links to its Tier-2 spec. The numerated sub-features are the units the
depth pass expands.

### A. [Configuration](blue-specs/configuration.md)
The three-state model that underlies everything: presets and user overrides as
sparse optionals, resolved field-by-field into the effective config the
renderer reads.
1. Data model (`LookAndFeel`, `Settings`, per-axis optionals)
2. Resolver semantics (field-by-field merge, `EffectiveConfig`)
3. Persistence & migration (sparse serialization; from `ThemeKind`)

### B. [Decorations](blue-specs/decorations.md)
The visual theme of windows and chrome. Extends the existing `Theme` struct.
1. Palette & gray ramp (steps, temperature, derived surfaces)
2. Bevel primitive in `canvas.v` (raised / sunken / groove + smoothing)
3. Window chrome (title bar, `title_align`, buttons, corners, shadow)
4. Cursor appearance (folds `cursor_fill`/`cursor_edge` into `Decor`)

### C. [Typography](blue-specs/typography.md)
Configurable type; currently a single fixed atlas.
1. Type configuration over the existing atlas (size / weight / smoothing)
2. Font data & multiple families *(deferred — needs new atlas data)*

### D. [Window handling](blue-specs/window-handling.md)
Window behavior policy. `Window` today has only `maximized`/`minimized`.
1. Window-shade (roll-up) — new `shaded` state + handler
2. Maximize / restore policy (respect panels / dock)
3. Title-bar interactions & button set (double-click incl. `hide`; stick button)
4. Focus model (policy, new-window focus, raise-on-focus, raise-on-click)
5. Window snapping & move/resize (edge/window snap; opaque vs outline)
6. Window keyboard shortcuts *(deferred)*

### E. [Shell](blue-specs/shell.md)
Panels that host ordered items. Refactors the monolithic `taskbar_element()`.
1. Panel model & layout engine (edge / size / align; autohide; reserve_space)
2. Item: system menu (Start orb / Apple / BeOS leaf)
3. Item: window list (taskbar buttons)
4. Item: launcher (Deskbar / WindowMaker strip; reuses `available_apps`)
5. Item: tray (status icons; notifications *(deferred)*)
6. Item: clock
7. Item: workspace switcher *(reserved / deferred)*

### F. [Menu system](blue-specs/menu-system.md)
Cross-cutting: hosts in the shell, triggered by window handling, extended by the
app protocol. Promoted to top level for that reason.
1. Menu model (the data a menu is)
2. Global menu host & placement (`global` / `in_window` / `none`)
3. System window menu (About / Close / Shade / Minimize / Zoom)
4. Per-application menus over the `VAPP` protocol *(deferred)*

### G. [Presets & registry](blue-specs/presets.md)
The registry mechanism and the concrete presets.
1. Registry mechanism (string-id lookup, registration)
2. Reference presets (Blue, Windows 2000, Platinum, BeOS, Default, macOS)
3. Settings / picker UI (registry-driven; inherited-vs-overridden display)

### H. [Desktop surface](blue-specs/desktop-surface.md)
The wallpaper plane and what sits on it — distinct from panels (E). Today
wallpaper is configured but lives in bare `Settings`; desktop icons are
hardcoded app shortcuts down the left edge with no show/hide.
1. Wallpaper (folded into the look-and-feel model as a configurable axis)
2. Desktop-icon content — configurable: app shortcuts **or** files/folders
3. Desktop-icon visibility & arrangement (show/hide, edge/grid/spacing)
4. Desktop context menu *(deferred; ties into F)*

---

## Fork-on-top strategy (summary)

- **New files carry the weight:** `lookandfeel.v` (model + registry + resolver),
  `blue.v` and the era presets, `canvas_bevel.v`, `panel.v` / `panel_items.v`,
  `menu.v`, `window_shade.v`, `desktop_surface.v`.
- **Existing files edited only at seams**, preferably reduced to delegation:
  `settings.v` (enum + `Theme` → registry + `Decor`; `theme()` → resolver),
  `wm.v` (`taskbar_element()` → panel renderer; `shortcut_elements()` → desktop
  surface; shade handler; maximize policy; menu host), `window.v` (`+shaded`),
  `settings_app.v` (registry-driven picker + new panes), `canvas.v` / `font.v`
  (bevel primitive; type knobs), `theme.v` (constants migrate into `Decor` and
  the `DesktopSurface` axis — see ISSUES.md ISSUE-6).

Full detail per file lives in the relevant Tier-2 doc.

---

## Phased delivery (summary)

Each phase is independently bootable, testable, and committed (per
`AGENTS.md`). Phases 1–2 build the two *systems*; everything after is
configuration and content on top. Detailed phase boundaries are owned by the
Tier-2 docs and finalized in the reconciliation pass.

1. **Look-and-feel skeleton** — model, registry, resolver, string-id selection,
   registry-driven picker; migrate Default + macOS unchanged. *No visual change.*
2. **Panel system** — refactor `taskbar_element()` into panel + item renderers;
   reproduce the current bar exactly, then add a top-bar preset.
3. **Blue decorations** — ramp + `bevel_rect` + Blue `Decor`.
4. **Menu system** — global + system window menu (per-app menus deferred).
5. **Window handling** — shade, maximize policy, double-click title.
6. **Desktop surface** — wallpaper as an axis, desktop-icon show/hide +
   arrangement (`shortcuts` mode; `files` mode deferred).
7. **Tray + launcher + typography knobs**, then the faithful era presets.

*(Planned / later: left-right & floating corner panels; per-app menus over
`VAPP`; multi-family fonts.)*

---

## Comparative basis & explicit non-goals

The feature surface was gap-checked against XFCE (xfce4-panel + xfwm4, the
closest analogue — composable panels over a themable window manager), with
GNOME, macOS, and WindowMaker as secondary references. Findings are logged in
[`blue-specs/ISSUES.md`](blue-specs/ISSUES.md) Round 4 (GAP-1..13). Adopted
items (panel autohide/reserve-space, window snapping, full focus model,
3-way title alignment, `hide` double-click, cursor theming) are threaded into
the relevant Tier-2 docs.

Explicit **non-goals** for the Blue look-and-feel system (recorded as decisions,
not oversights):
- **Multi-monitor** panels/output selection — Vinix is a single `/dev/fb0`
  framebuffer today (GAP-3).
- **Workspaces / virtual desktops** — a compositor capability Vinix lacks; Blue
  only *reserves* the `stick` button and a `workspace_switcher` item so a future
  workspace engine can surface without a model change (GAP-12).
- **Swappable icon/cursor *shape* sets** and **multi-family fonts** — need new
  embedded data, deferred alongside C2 (GAP-11).

---

## Cross-cutting open questions

Owned here until the reconciliation pass resolves them; individual Tier-2 docs
may raise their own.

- Gray ramp size and temperature (tuned by screenshot, not fixed here).
- Blue's own default shell arrangement (a flagship design choice, not dictated
  by history like the era presets).
- Whether Settings visually shows "inherited vs overridden" per setting, with a
  per-setting reset (recommended).
- Persistence format for sparse override state.
