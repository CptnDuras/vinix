# F. Menu system

Promoted to a top-level feature because it is **cross-cutting**: it is *hosted*
by the shell (the global menu bar is a panel item), *triggered* by window
handling (the window menu), and *extended* by the compositor⇄app protocol
(per-app menus). It owns **no configuration axis of its own**; its only
user-visible knob is `Behavior.menu_placement` (an axis field in D).

Touches: new `menu.v` (model + rendering), `wm.v` (menu host + window menu
trigger), `panel_items.v` (the `app_menu` slot renderer), `app_process.v`
(`VAPP` extension — deferred). **Depends on: A (Configuration), B (Decor), D
(window handling triggers the window menu), E (Shell exposes the `app_menu`
slot F targets).** Depended on by: nothing declares F as a dependency — F
targets E's slot rather than being depended upon, which is what keeps the graph
acyclic (ISSUES.md ISSUE-2).

**Direction of dependency (ISSUES.md ISSUE-2):** F1's `Menu` type is pure data
and depends on nothing. E references that type to type its `app_menu` slot. F2
depends on E to locate the slot and fills it. So the only edge is F→E, not a
cycle.

## Sub-features

1. **Menu model.** What a menu *is*: a tree of items (label, action id,
   enabled, separator, submenu, checkmark). Platform-independent, encoded the
   way the rest of the desktop encodes UI. Pure data type, no dependency on E or
   F's hosts. *Deep pass defines: the menu/item structs, action routing (reuses
   the existing action-id convention), and how a menu is rendered by the
   software renderer (popup surface, hover, submenu open).*
   - **Acceptance criteria:** (a) a `Menu` can be constructed with nested
     submenus, separators, disabled and checked items; (b) `Menu` has no
     dependency on Shell or window types (importable standalone); (c) rendering
     a `Menu` produces a popup element tree with one element per visible item.
   - **Testing:** unit test builds a nested menu and asserts the flattened
     visible-item count and that a disabled item carries the disabled style; a
     compile-level check that `menu.v` imports neither `panel` nor `wm` types.

2. **Global menu host & placement.** `Behavior.menu_placement ∈ {global,
   in_window, none}`. `global` renders the focused window's menu in a top-bar
   `app_menu` slot (Platinum / GNOME); `in_window` renders it in the window's
   title area (Windows / BeOS); `none` shows no menu bar. *Deep pass defines:
   how the focused window's menu is collected and handed to the active host, the
   `app_menu` slot renderer, and the in-window title-area layout.*
   - **Acceptance criteria:** (a) `global` places the focused window's menu in
     the top-panel `app_menu` slot and nothing in the title area; (b)
     `in_window` places it in the title area and leaves the `app_menu` slot
     empty; (c) `none` produces no menu bar anywhere; (d) changing the focused
     window updates the hosted menu.
   - **Testing:** with a stub window carrying a known menu, assert per placement
     which host contains the menu tree and which is empty; assert focus change
     swaps the hosted menu.

3. **System window menu.** A menu the system provides for every window —
   About / Close / Shade / Minimize / Zoom — so the menu host is demonstrably
   functional independent of per-app menus, and so window-handling (D) actions
   have a menu path. **Its actions invoke D's handlers; it does not draw its own
   chrome button — it is triggered by a logical button in D3's button set (if
   present) and/or a right-click on the title bar (ISSUES.md ISSUE-4).** *Deep
   pass defines: the fixed item set, how it composes with a per-app menu when
   both exist.*
   - **Acceptance criteria:** (a) every window has the five-item system menu
     regardless of preset; (b) Close/Shade/Minimize/Zoom invoke the exact D
     handlers (close, shade toggle, minimize, toggle_maximize); (c) disabled
     items reflect state (e.g. Shade disabled when `shade_enabled` is false).
   - **Testing:** assert the system menu has the five expected action ids; a
     test that invoking each action id routes to the corresponding D handler
     (via the existing action-routing path); assert Shade item disabled when the
     resolved `Behavior.shade_enabled` is false.

4. **Per-application menus over `VAPP` *(deferred)*.** Extending the
   compositor⇄app protocol (`app_process.v`, the `VAPP` wire format, currently
   version 3) so an app declares its menu tree alongside its element tree. The
   largest follow-on; reserved in the model now. *Deep pass defines: the
   protocol addition, version bump, and how app menu actions route back to the
   app.*
   - **Acceptance criteria (deferred):** (a) `VAPP` version increments and old
     clients still function (menu absent); (b) an app-declared menu round-trips
     over the pipe and renders in the active host; (c) selecting an app menu
     item delivers the action to the owning app process.
   - **Testing (deferred):** extend `app_process_integration.v` to encode/decode
     a menu payload and assert round-trip; assert version negotiation with a
     menu-less client.

## Open questions

- System window menu trigger: right-click title bar, a dedicated D3 button, or
  both? (Leaning: both — right-click always, button optional per button_set.)
- When both system and per-app menus exist under `in_window`, compose with the
  system menu as a leading system item (Win system-menu style).
- Does `global` placement also show the system_menu's items? (Leaning: no; the
  system_menu item stays a separate shell item.)
