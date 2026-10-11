#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Runs the Blue look-and-feel pure-logic test suite.
#
# The Blue system is built so its model/logic (configuration & resolver, gray
# ramp, panel layout math, bevel primitive, window-shade, maximize policy,
# focus model, menu model) has no ui2 dependency and compiles under the base V
# compiler. This lets those units be verified without the full desktop harness
# (desktop/tools/test-utilities.sh), which requires `v -new-compiler` (the V3
# frontend for the Calculator's $vml) that is not always present.
#
# The ui2-coupled glue (chrome drawing, panel tree assembly, menu popups,
# input wiring) is exercised by the full harness on a V3 build.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
v=${V:-v}
command -v "$v" >/dev/null 2>&1 || { echo 'ERROR: V is required.' >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

d="$root/desktop"
# Pure-logic modules and their tests (no ui2).
for f in \
    lookandfeel.v lookandfeel_test.v \
    blue_ramp.v blue_ramp_test.v \
    panel_layout.v panel_layout_test.v \
    window_shade.v window_shade_test.v \
    maximize_policy.v maximize_policy_test.v \
    window_snap.v window_snap_test.v \
    focus_model.v focus_model_test.v \
    menu.v menu_test.v \
    chrome_model.v chrome_model_test.v \
    canvas.v canvas_bevel.v canvas_bevel_test.v
do
    cp "$d/$f" "$work/"
done

# The registry index bridge lives in lookandfeel_theme.v alongside preset_theme,
# which needs the ui2-coupled Theme struct. Provide just the index helpers here
# so the resolver tests can run standalone. (Kept identical to the real ones.)
cat > "$work/bridge.v" <<'EOF'
module main

fn registry_index_of(id string) int {
	for i, lnf in lookandfeel_registry {
		if lnf.id == id {
			return i
		}
	}
	return 0
}

fn registry_id_at(index int) string {
	if index < 0 || index >= lookandfeel_registry.len {
		return default_preset_id
	}
	return lookandfeel_registry[index].id
}
EOF

printf "Module { name: 'blue_pure_tests' }\n" > "$work/v.mod"
"$v" -nocache test "$work"
