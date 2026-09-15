// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (c) 2026 Vinix contributors
//
// Blue Window handling — focus model (spec D4).
//
// The focus/raise decisions expanded to match mature window managers:
// click-to-focus vs focus-follows-mouse, and independent raise-on-focus /
// raise-on-click. Pure predicates over the resolved Behavior so they are
// unit-testable without ui2; wm.v calls them from the input path.
module main

// FocusInputs describes a pointer event the WM must react to.
struct FocusInputs {
	is_click        bool // true = a button press; false = a bare move
	over_window_id  int  // window under the pointer (0 = none)
	current_focus   int
	frame_body_hit  bool // the click landed on the window body (not decorations)
}

// FocusDecision is what the WM should do in response.
struct FocusDecision {
	new_focus int
	raise     bool
}

// decide_focus applies the resolved focus policy to a pointer event.
//
//   click_to_focus      : focus (and raise per raise_on_click) only on a click
//   focus_follows_mouse : focus the window under the pointer on any move;
//                         raising still gated on raise_on_focus / a click
fn decide_focus(in_ FocusInputs, policy FocusPolicy, raise_on_focus bool, raise_on_click bool) FocusDecision {
	match policy {
		.click_to_focus {
			if !in_.is_click {
				return FocusDecision{
					new_focus: in_.current_focus
					raise:     false
				}
			}
			// A click focuses the window under the pointer. Raise if
			// raise_on_click, or if it's a decoration click (always raises).
			raise := raise_on_click || !in_.frame_body_hit
			return FocusDecision{
				new_focus: in_.over_window_id
				raise:     raise && in_.over_window_id != 0
			}
		}
		.focus_follows_mouse {
			// The window under the pointer receives focus on any event.
			mut raise := false
			if in_.is_click {
				raise = raise_on_click || !in_.frame_body_hit
			} else {
				raise = raise_on_focus
			}
			return FocusDecision{
				new_focus: in_.over_window_id
				raise:     raise && in_.over_window_id != 0
			}
		}
	}
}
