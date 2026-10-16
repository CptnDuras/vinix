# D. Window handling (`Behavior`)

Window behavior policy. Today `Window` (in `window.v`) has only `maximized` and
`minimized`, and `wm.v` hardcodes the maximize target as
`canvas.height - taskbar_height`. Blue makes these policies and adds
window-shade. **`Behavior` also carries `menu_placement`** (the Menu system F
owns no axis of its own — see BLUE.md canonical model).

Touches: `window.v` (new state), `wm.v` (handlers, maximize math),
`switcher.v`/taskbar (respect new state), `settings.v` (`Behavior` axis).
Depends on: A (Configuration); D2 depends on E (panels) for "respect panels".
Depended on by: F (the window menu triggers these handlers; `menu_placement`
lives here).

**Button ownership (ISSUES.md ISSUE-4):** D3 owns the *logical button set*
(which buttons exist and their order). B3 owns how a button is *drawn*. F3's
system window menu is *triggered* by the logical window-menu button (if the set
includes it) and/or a title-bar right-click; F does not draw chrome.

## Sub-features

1. **Window-shade (roll-up).** New `shaded bool` + `restore_height_shade` on
   `Window`; a handler collapses the window to its title-bar height and back.
   `Behavior.shade_enabled`. *Deep pass defines: the `Window` field additions,
   the shade handler beside `toggle_maximize`, interaction with
   minimize/maximize, and how a shaded window renders (title only) and
   hit-tests.*
   - **Acceptance criteria:** (a) shading a window sets height to the title-bar
     height and stores the prior height; (b) unshading restores the exact prior
     height; (c) a shaded window shows only its title bar and hit-tests only
     there; (d) shade is a no-op when `shade_enabled` is false.
   - **Testing:** unit test toggles shade and asserts height == title height
     then restored height; asserts body elements absent while shaded; asserts
     no-op when disabled.

2. **Maximize / restore policy.** `Behavior.maximize_policy ∈ {fill_screen,
   respect_panels, respect_dock}` replaces the hardcoded fill so a top bar
   and/or dock reduce the maximized area. *Deep pass defines: how the policy
   queries the resolved shell layout for occupied edges, and the
   restore-geometry bookkeeping.*
   - **Acceptance criteria:** (a) `fill_screen` reproduces today's maximize
     (full width, height − bottom taskbar) when the default shell has a bottom
     bar; (b) `respect_panels` subtracts every occupied panel edge (top and
     bottom); (c) restore returns the pre-maximize geometry exactly.
   - **Testing:** with a two-panel shell config, assert the maximized rect
     equals screen minus both panels under `respect_panels`, and equals
     today's rect under `fill_screen` with the default shell.

3. **Title-bar interactions & button set.** `Behavior.title_double_click ∈
   {shade, hide, maximize, none}` (`hide` = minimize; parity with xfwm4 — see
   ISSUES.md GAP-8) and `Behavior.button_set` (an ordered list of logical
   buttons: `close, minimize, zoom, window-menu, stick`). The window-menu button
   triggers F3; `stick` (all-workspaces) is **reserved, a no-op until workspaces
   exist** (GAP-10/GAP-12). A button absent from the set is simply not drawn
   (this is xfwm4's "Hidden area"). *Deep pass defines: routing the title
   double-click in `wm.v`, how the chrome builder (B3) consumes the set,
   defaults per preset.*
   - **Acceptance criteria:** (a) double-click on the title runs the configured
     action (shade/hide/maximize/none); (b) the chrome renders exactly the
     buttons in `button_set`, in order; (c) each button's click routes to its
     handler; (d) `stick` renders but is inert until workspaces land.
   - **Testing:** assert double-click routing per setting incl. `hide`→minimize;
     assert the title-bar child buttons match `button_set` ids/order
     (cross-checks B3's rendering test); assert each button id routes to the
     correct handler; assert `stick` is a no-op.

4. **Focus model.** Expanded to match mature WMs (ISSUES.md GAP-7):
   `Behavior.focus_policy ∈ {click_to_focus, focus_follows_mouse}`,
   `focus_new_windows bool` (focus a newly opened window), `raise_on_focus bool`
   (+ reserved delay), `raise_on_click bool` (raise when clicking the frame body,
   not just decorations). *Deep pass defines: where focus is decided in the
   input path, and the raise interactions.*
   - **Acceptance criteria:** (a) `click_to_focus` reproduces today's behavior
     (click focuses+raises); (b) `focus_follows_mouse` focuses the window under
     the pointer; (c) `raise_on_focus`/`raise_on_click` independently control
     stacking; (d) `focus_new_windows` focuses an opened window without pointer
     movement.
   - **Testing:** simulate pointer move/click and assert `focus` + stack order
     per combination of the four fields; assert `focus_follows_mouse` without
     `raise_on_focus` does not reorder the stack; assert a newly opened window is
     focused iff `focus_new_windows`.

5. **Window snapping & move/resize.** New (ISSUES.md GAP-5). `Behavior`:
   `snap_to_edges bool`, `snap_to_windows bool`, `snap_distance int`, and
   `opaque_move_resize bool` (outline vs live content while dragging). *Deep pass
   defines: the snap test during a title-bar drag, the distance threshold, and
   the outline-drag rendering path.*
   - **Acceptance criteria:** (a) a window dragged within `snap_distance` of a
     screen edge snaps flush; (b) with `snap_to_windows`, borders snap to another
     window's border; (c) snapping off resumes free movement past the threshold;
     (d) `opaque_move_resize=false` draws an outline instead of moving content.
   - **Testing:** unit test feeds a drag path near an edge and asserts the
     resulting position is snapped; asserts no snap when the flags are false.

6. **Window keyboard shortcuts *(deferred)*.** New (ISSUES.md GAP-6). A binding
   model mapping key chords to window actions (close, shade, minimize, maximize,
   focus-next, etc.), so window handling is reachable from the keyboard. The
   desktop today uses a few hardcoded chords; this generalizes them. A full
   editable table is later. *Deep pass (deferred) defines: the binding model,
   default chords, and the input-path dispatch.*
   - **Acceptance criteria (deferred):** (a) a default chord invokes its window
     action; (b) bindings resolve through the config model; (c) no chord fires
     while an app holds the keyboard.
   - **Testing (deferred):** assert a default chord routes to its handler; assert
     suppression while an app is focused.

## Open questions

- Does shade coexist with maximize (shade a maximized window?) or are they
  mutually exclusive? (Leaning: coexist — shade stores the maximized height.)
- Snap-to-windows across the whole stack vs only the topmost under the pointer.
- Workspaces (GAP-12) are **out of Blue's look-and-feel scope** — a separate
  compositor feature. D reserves the `stick` button and defers the keyboard
  model so it can integrate later without a model change.
