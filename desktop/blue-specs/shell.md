# E. Shell — panels & items

Panels are placeable bars that host ordered items. This generalizes the current
`wm.v` `taskbar_element()` — a monolith that hardcodes start-orb → window-buttons
→ clock at the bottom with a `dock` boolean as the only alternate — into a
composable system. Because items are independent, Windows (system_menu +
window_list in one bottom bar), classic Mac (top bar, no window_list), and BeOS
(both folded into one corner strip) are all configuration.

Touches: `wm.v` (`taskbar_element()` → thin delegation into the panel
renderer), new `panel.v` / `panel_items.v`, `start_menu.v` (system_menu item),
`clock.v` (clock item), `app.v` (launcher reuses `available_apps`),
`settings.v` (`Shell` axis). **Depends on: A (Configuration), B (Decor for
ramp/bevels + the shared `icon_tile` renderer).** Depended on by: D2 (maximize
respects panels), F (targets the `app_menu` slot E exposes), G (presets author
shell layouts).

**Dependency to F (ISSUES.md ISSUE-2, cycle broken):** E does **not** depend on
the Menu system's internals. E exposes a generic `app_menu` panel-item slot that
renders whatever `Menu` value it is handed. `Menu` is a pure data type (defined
in F1) with no dependency on E, so E referencing the type is not a cycle. F
depends on E to know *where* the slot is and hands it the focused window's menu.

**Launcher vs desktop icons (ISSUES.md ISSUE-3):** the launcher item (E4) renders
`icon_tile`s using B's shared renderer. E4 owns the *pinned-set* model. The
desktop `shortcuts` mode (H2) also uses the shared `icon_tile` renderer but does
**not** reuse E4's pinned set — it reads `available_apps` directly. Shared
renderer, independent hosts and config.

Pragmatic first cut: zero, one, or two `full_bar` panels (top and/or bottom)
with leading/center/trailing item slots. Left/right edges and true floating
corner docks are *(planned)*.

## Sub-features

1. **Panel model & layout engine.** `Panel{ id, edge, style, size, align, items
   []PanelItemRef, autohide, reserve_space, background?, opacity? }`; the generic
   layout math refactored out of `taskbar_element()`. The refactor must reproduce
   the current taskbar/dock exactly as the default config before any new
   arrangement is added. Informed by xfce4-panel (ISSUES.md GAP-1..4):
   - `autohide ∈ {never, intelligent, always}` — `intelligent` hides when the
     focused window overlaps the panel.
   - `reserve_space bool` — whether the panel reduces the maximize area (ties to
     D2; an autohidden/non-reserving panel does not).
   - `edge` reserves `top, bottom` for the pragmatic cut and `left, right`
     (vertical) + a Deskbar mode as *(planned)* values, so the model needs no
     reshaping later (GAP-2).
   - `background?`/`opacity?` — panels derive appearance from `Decor` by default
     (coherence over per-panel styling); these optional overrides are reserved
     for later (GAP-4).
   - **Multi-monitor (output/span) is explicitly OUT OF SCOPE** — Vinix is a
     single `/dev/fb0` framebuffer today (GAP-3); revisit when the compositor
     gains multiple outputs.
   *Deep pass defines: the structs, the layout algorithm, hit routing, the
   autohide overlap test, and the deletion-and-delegation edit to `wm.v`.*
   - **Acceptance criteria:** (a) with the default shell config the produced
     element tree is byte-for-byte equivalent to today's `taskbar_element()`
     output (same ids, rects, styles); (b) items resolve into leading/center/
     trailing slots with today's space-sharing; (c) a two-panel (top+bottom)
     config places each panel at its edge without overlap; (d) hit routing to an
     item is unchanged for the default config; (e) an `intelligent`/`always`
     panel with `reserve_space=false` does not reduce the maximize area (checked
     jointly with D2).
   - **Testing:** golden-tree test comparing default-config panel output against
     the current `taskbar_element()` (guards the no-regression requirement);
     layout test asserting slot positions for a synthetic multi-item panel;
     an autohide test asserting a panel hides when a stub focused window overlaps
     it; the existing taskbar tests (`utilities_test.v`) must still pass.

2. **Item: system menu.** The top-left icon / Apple menu / BeOS leaf / Start orb
   — a refactor of the existing Start button into a placeable item. Separate item
   from window_list. *Deep pass: the item renderer, its menu trigger.*
   - **Acceptance criteria:** (a) renders the Start orb identically in the
     default config; (b) clicking it toggles the start menu as today; (c) can be
     placed in a top panel without a window_list present.
   - **Testing:** assert the `action_start_toggle` button exists with today's id
     and geometry in the default config; a config with only system_menu (no
     window_list) still builds and the orb is present.

3. **Item: window list.** The taskbar buttons — refactor of `taskbar_entries()`
   into an item; `standard` vs `combined` modes retained. Separable from
   system_menu (Mac omits it entirely). *Deep pass: renderer, entry model,
   share-space behavior within a panel slot.*
   - **Acceptance criteria:** (a) both modes produce today's entries; (b) a
     config omitting window_list builds with no task buttons and no gap; (c)
     entries share slot width using today's min-width rule.
   - **Testing:** reuse existing window-list assertions from `utilities_test.v`/
     `switcher_test.v`; add a test that a window_list-absent config yields zero
     task buttons.

4. **Item: launcher.** A pinned-app strip (BeOS Deskbar / WindowMaker dock),
   rendering `icon_tile`s (B) from a pinned set drawn from `available_apps`.
   *Deep pass: pinned-set model, renderer, relationship to wallpaper shortcuts.*
   - **Acceptance criteria:** (a) a pinned set of app ids renders one
     `icon_tile` each in order; (b) launching from a tile opens the app as the
     wallpaper shortcut does; (c) the launcher uses B's `icon_tile` (no private
     icon renderer).
   - **Testing:** build a launcher with a fixed pinned set and assert one tile
     per id in order; assert the launch action id matches the shortcut path.

5. **Item: tray *(new)*.** Status / notification items in a panel slot. *Deep
   pass: what a tray item is, who registers them, initial built-in items.*
   Following xfce4-panel's Notification Area, **notifications are a *(deferred)*
   extension of the tray item** (ISSUES.md GAP-13) — the first cut is status
   icons only (battery/wifi candidates); transient notification popups come
   later, not as a separate axis.
   - **Acceptance criteria:** (a) an empty tray occupies no space; (b) a
     registered status item renders in the trailing slot; (c) tray items do not
     overlap the clock.
   - **Testing:** assert empty tray adds no children; assert a stub status item
     appears with a bounded rect that does not intersect the clock rect.

6. **Item: clock.** Refactor of the existing clock labels into a placeable item.
   *Deep pass: renderer, format config, placement.*
   - **Acceptance criteria:** (a) renders today's time/date labels with today's
     ids in the default config; (b) stays within its reserved trailing width at
     200% scale (preserves the existing M1 requirement).
   - **Testing:** reuse the existing clock-at-200% test; assert `clock.time` /
     `clock.date` ids and geometry in the default config.

7. **Item: workspace switcher *(reserved / deferred)*.** A pager item (as in
   xfce4-panel / GNOME / WindowMaker). **Reserved only** (ISSUES.md GAP-12):
   workspaces are a compositor capability Vinix lacks today and are **out of
   Blue's look-and-feel scope**; the item kind is reserved in the model so a
   later workspace engine can surface here without reshaping the panel. Renders
   nothing until workspaces exist.
   - **Acceptance criteria (deferred):** (a) the `workspace_switcher` item kind
     exists in the panel model and a panel containing it emits zero children
     while no workspace engine is present; (b) reserving it requires no
     panel-model reshaping when workspaces later land.
   - **Testing (deferred):** assert a panel containing a `workspace_switcher`
     item produces no child elements today; assert the item kind is accepted by
     the panel model without error.

## Open questions

- Center-slot layout math when leading/trailing slots compete for space.
- Panel-per-edge maximum (one per edge?) for the pragmatic cut. (Leaning: one.)
