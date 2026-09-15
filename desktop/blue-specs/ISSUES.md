# Blue spec — reconciliation issues

Conflicts, overlaps, and disagreements found while reconciling the Blue specs.
Each issue records the problem, the affected specs, the resolution, and status.
The reconciliation pass loops until every issue is `RESOLVED`.

Status legend: `OPEN` · `RESOLVED` · `DEFERRED` (needs a human design call).

---

## Round 1 — structural agreement

### ISSUE-1 — Tier-1 map omits Desktop surface (H)  ·  RESOLVED
BLUE.md predates the addition of feature H. Its axis sentence ("decorations,
typography, window handling, the shell, and menus"), the fork-on-top summary,
and the phase list all omit H; `configuration.md` says "depended on by all of
B–G" (should be B–H).
- Affected: BLUE.md, configuration.md.
- Resolution: add H everywhere the axis set is enumerated; the model has **five
  axes** (Decor, Typography, Behavior, Shell, DesktopSurface) plus the two
  cross-cutting concerns (Configuration A, Menu system F) that are not axes.
  See ISSUE-5 for the axis-set canonicalization.

### ISSUE-2 — Dependency cycle E ↔ F  ·  RESOLVED
`shell.md` declared E depends on F (needs the menu host); `menu-system.md`
declared F depends on E (the global bar is a panel item). Circular.
- Affected: shell.md, menu-system.md.
- Resolution: **break the cycle by direction of data, not of code.** The Shell
  (E) owns a generic `app_menu` *item slot* that renders whatever menu model it
  is handed; it does not depend on F's internals — it depends only on F's
  **menu-model type** (A-level vocabulary). The Menu system (F) depends on E to
  know *where* the `app_menu` slot is. Canonical dependency:
  - E depends on: A, B. E exposes an `app_menu` slot that accepts a `Menu`.
  - F depends on: A, B, D, E. F produces the `Menu` and targets the slot.
  The shared `Menu` type is defined in F1 (menu model) but is a pure data type
  with no dependency on E, so referencing it from E is not a cycle.

### ISSUE-3 — Launcher (E4) vs desktop icons (H2/H3) overlap  ·  RESOLVED
Both reuse `available_apps`/`AppFactory` and both render app-icon tiles. Risk of
two divergent icon renderers and two pinned-set models.
- Affected: shell.md (E4), desktop-surface.md (H2, H3).
- Resolution: **one shared icon-tile renderer, two hosts.** A single
  `icon_tile` renderer (app glyph + label + hover/press) is defined once (owned
  by B, Decorations, since it is a visual primitive). E4 (launcher) and H2/H3
  (desktop icons) are two *hosts* that place `icon_tile`s; they share the
  renderer but keep independent placement/config. The "pinned set" model is
  owned by E4; the desktop `shortcuts` mode (H2) reuses `available_apps`
  directly and does **not** share E4's pinned-set. Stated in both docs.

### ISSUE-4 — Window menu (F3) vs title-bar buttons (D3) chrome ownership  ·  RESOLVED
Both may want a title-bar "menu button," and both touch chrome.
- Affected: window-handling.md (D3), menu-system.md (F3), decorations.md (B3).
- Resolution: **chrome geometry is owned by B3 (window chrome).** D3 owns the
  *button set* (which logical buttons exist and their order) as a `Behavior`
  field; B3 owns *how* a button is drawn. F3's window menu is *triggered* by one
  of D3's logical buttons (the "window-menu" button, if present) and/or a
  right-click on the title bar; F3 does not draw its own chrome button. The
  logical button list lives in D3; its rendering in B3; its menu content in F3.

### ISSUE-5 — Wallpaper/DesktopSurface not in the LookAndFeel axis set  ·  RESOLVED
`desktop-surface.md` folds wallpaper into "the look-and-feel model," but
`configuration.md`'s `LookAndFeel`/`Settings` list only Decor/Typography/
Behavior/Shell. `presets.md` says G "depends on A–F" (omits H).
- Affected: configuration.md (A1), presets.md, desktop-surface.md.
- Resolution: **canonical axis set = five axes**: `Decor`, `Typography`,
  `Behavior`, `Shell`, `DesktopSurface`. `LookAndFeel` and `Settings` carry an
  optional field per axis. A (Configuration) and F (Menu system) are **not
  axes**: A is the meta-model; F's user-visible knob is `menu_placement`, which
  lives in the `Behavior` axis (already the case in D/F). Wallpaper +
  icon-content + arrangement are fields of the `DesktopSurface` axis. Update A1,
  and change G's dependency to "A–H."

### ISSUE-6 — `theme.v` ownership split between B and H  ·  RESOLVED
B (Decorations) claims `theme.v`; H3 edits the shortcut-geometry constants in
`theme.v`.
- Affected: decorations.md, desktop-surface.md.
- Resolution: **`theme.v` constants are being retired into resolved config.**
  The color/measurement constants migrate into `Decor` (B); the shortcut-geometry
  constants migrate into the `DesktopSurface` axis (H3). Neither "owns
  `theme.v`"; both *remove from it* into their respective axis. Stated as a
  shared migration note in both docs so the edits do not collide.

---

## Round 2 — acceptance criteria & testing coverage

(Recorded after the criteria pass; any sub-feature lacking testable acceptance
criteria is logged here until fixed.)

## Round 3 — independent audit findings

Independent auditor (read-only) traced the full dependency graph and verified
acceptance-criteria coverage and issue-resolution consistency.

- **AUDIT-1 (MINOR) — RESOLVED.** BLUE.md's dependency line read `A → {B,C,D,H}`,
  omitting E, contradicting shell.md (E depends on A) and configuration.md (A
  depended on by all of B–H). Fixed: `A → {B, C, D, E, H}`.
- **AUDIT-2 (MINOR) — RESOLVED.** BLUE.md omitted the `E → D2` edge that
  window-handling.md and shell.md both declare. Fixed: added `E → D2` (one-way
  layout query; graph still acyclic).

Auditor confirmed clean: five-axis set identical across BLUE/configuration/
presets; E↔F cycle correctly broken to F→E only; ISSUE-1..6 resolutions applied
consistently in both spanned docs; no factual conflicts; every numbered
sub-feature carried acceptance + testing bullets at the time of Round 3.
(Round 4 later added E7, which was given its deferred-style bullets after the
re-audit — see below.)

## Round 4 — comparative gap analysis (other systems)

Compared the spec surface against XFCE (xfce4-panel + xfwm4 preferences, the
closest analogue: a composable-panel + themable-WM desktop), with GNOME, macOS
and WindowMaker as secondary references. Each gap is classified:
**ADOPT** (add to specs now), **DEFER** (reserve, schedule later), or
**OUT-OF-SCOPE** (deliberately not doing; recorded so it is a decision, not an
oversight).

### GAP-1 — Panel autohide  ·  ADOPT  ·  RESOLVED
XFCE panels hide Never / Intelligently (when focused window overlaps) / Always,
plus "keep panel above windows." Blue's Shell (E) had no autohide, and this
directly interacts with D2 maximize policy. Resolution: add `autohide ∈
{never, intelligent, always}` and `reserve_space bool` to the `Panel` model
(E1); note the D2 interaction (a non-reserving/autohidden panel does not reduce
the maximize area). Applied to shell.md E1 and window-handling.md D2.

### GAP-2 — Panel orientation / Deskbar mode  ·  ADOPT (partial)  ·  RESOLVED
XFCE panels are Horizontal / Vertical / Deskbar. Blue's pragmatic cut is
top/bottom full bars only. Resolution: keep the pragmatic cut, but the `Panel`
model already carries `edge`; explicitly record left/right (vertical) and
Deskbar as the `edge` values reserved for the *(planned)* phase, so the model
does not need reshaping later. Applied to shell.md E1.

### GAP-3 — Multi-monitor (Output / Span)  ·  OUT-OF-SCOPE  ·  RESOLVED
XFCE panels target an output and can span monitors. Vinix is a single
framebuffer today (`/dev/fb0`); multi-output is a compositor-level capability
Blue does not have. Recorded as explicitly out of scope in shell.md so it is a
decision. Revisit if/when the compositor gains multiple outputs.

### GAP-4 — Panel appearance & opacity  ·  ADOPT (via Decor)  ·  RESOLVED
XFCE panels have their own background (solid/image/system) + hover/leave
opacity. Blue panels implicitly inherit `Decor`. Resolution: panels derive
appearance from `Decor` ramp by default (intentional — coherence over
per-panel styling), but reserve an optional per-panel background override and
opacity in the `Panel` model for later. Applied to shell.md E1.

### GAP-5 — Window snapping  ·  ADOPT  ·  RESOLVED
xfwm4 snaps window borders to screen edges / other windows while moving. Blue's
Behavior (D) had no snapping. Resolution: add a new sub-feature D5 "Window
snapping & move/resize" (edge/window snap distance; opaque-vs-outline
move/resize as a sub-option). Applied to window-handling.md.

### GAP-6 — Keyboard shortcuts for window actions  ·  DEFER  ·  RESOLVED
xfwm4 exposes a full editable window-action shortcut table. Blue's specs
describe no keyboard model at all (the desktop today uses a few hardcoded
chords). Resolution: add a reserved sub-feature D6 "Window keyboard shortcuts"
marked *(deferred)* — the model should exist so shade/min/max/close/focus have
key bindings, but authoring a full editor is later. Applied to window-handling.md.

### GAP-7 — Focus model completeness  ·  ADOPT  ·  RESOLVED
xfwm4 separates: focus model (click / follows-mouse), **new-window focus**,
**raise-on-focus (+delay)**, **raise-on-click**. Blue's D4 collapsed these.
Resolution: expand D4 to carry `focus_policy`, `focus_new_windows bool`,
`raise_on_focus bool`, `raise_on_click bool`. Applied to window-handling.md D4.

### GAP-8 — Double-click action missing "hide"  ·  ADOPT  ·  RESOLVED
xfwm4 double-click: shade / hide / maximize / none. Blue D3 had shade /
maximize / none. Resolution: add `hide` (= minimize) to `title_double_click`.
Applied to window-handling.md D3.

### GAP-9 — Title alignment 3-way  ·  ADOPT  ·  RESOLVED
xfwm4 offers left/center/right title alignment; Blue's `Decor` had only
`title_centered bool`. Resolution: replace with `title_align ∈ {left, center,
right}` in B3 (keep `title_centered` as a compatibility mapping during
migration). Applied to decorations.md B3.

### GAP-10 — Extra title-bar buttons (Menu, Stick)  ·  ADOPT  ·  RESOLVED
xfwm4's button layout includes Menu (window menu) and Stick (all-workspaces)
buttons and a Hidden area. Blue D3's `button_set` listed close/minimize/zoom/
window-menu. Resolution: the window-menu button is already covered (ties to
F3); add `stick` as a reserved button (no-op until workspaces exist, GAP-12);
the "Hidden area" concept = buttons simply absent from the ordered set.
Applied to window-handling.md D3.

### GAP-11 — Cursor & icon themes  ·  DEFER (cursor) / note (icon)  ·  RESOLVED
XFCE themes five things: WM decorations, widgets, **cursors**, notifications,
**icons**. Blue covers decorations+widgets (Decor) and type. The Vinix
compositor draws its own cursor (`cursor_fill`/`cursor_edge` in `theme.v`) and
its own app glyphs. Resolution: add a reserved `Decor` sub-area for **cursor
appearance** (folds the existing cursor constants into `Decor`, themable per
preset) — small, ADOPT into B; a full swappable *icon theme* is DEFER (needs
icon data like the deferred font families, C2). Applied to decorations.md.

### GAP-12 — Workspaces / virtual desktops  ·  DEFER  ·  RESOLVED
XFCE/GNOME/WindowMaker all have virtual desktops + a switcher plugin +
wrap-workspaces. Blue has no workspace concept. This is a **window-management
capability the compositor lacks today**, not just a look-and-feel knob.
Resolution: DEFER as a cross-feature *(planned)* — reserve a `workspace_switcher`
shell item (E) and the `stick` button (D3/GAP-10) so the model anticipates it,
but the workspace engine itself is out of the Blue look-and-feel scope and
belongs to a separate compositor feature. Recorded in shell.md and
window-handling.md as reserved.

### GAP-13 — Notifications  ·  DEFER  ·  RESOLVED
XFCE has a notifications theme/plugin. Blue's `tray` item (E5) is the natural
home for a notification surface but the specs describe only status icons.
Resolution: note in E5 that notifications are a *(deferred)* extension of the
tray item, not a separate axis.



### Round 4 re-audit
Independent auditor re-traced the graph and coverage after the gap edits:
AGREEMENT (BLUE.md lists match Tier-2 B=4/C=2/D=6/E=7), DEPENDENCY GRAPH
(acyclic), ISSUE CONSISTENCY (all GAP-1..13 present in named docs), and
CONTRADICTIONS (workspaces triangle agrees) all PASS. One MINOR: E7 lacked
acceptance/testing bullets — **fixed** (deferred-style bullets added). Stale
Round-3 coverage note corrected. Re-audit otherwise clean.
