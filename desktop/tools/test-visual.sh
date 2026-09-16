#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Runs the Blue programmatic visual UI-surface test: renders each preset to a
# canvas and asserts signature pixels. Set VINIX_SNAPSHOT_DIR to also dump a PNG
# per preset. Same staging as test-utilities.sh (needs V + third_party/ui2).
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
v=${V:-v}
command -v "$v" >/dev/null 2>&1 || { echo 'ERROR: V is required.' >&2; exit 1; }
[ -f "$root/third_party/ui2/v.mod" ] || {
    echo 'ERROR: visual tests require third_party/ui2.' >&2; exit 1;
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$root/desktop/tools/stage_ui2.py" \
    "$work/modules/ui2" "$root/third_party/ui2" \
    "$root/desktop/tools/ui2_headless_bounds.v"
mkdir "$work/ui"
python3 "$root/desktop/tools/stage_app.py" "$work/ui" "$root/desktop" \
    "$root/third_party/ui2/examples/calculator" >/dev/null
rm -f "$work/ui/main.v"
cp "$root/desktop/tools/tests/visual_test.v" "$work/ui/"
printf "Module { name: 'visual_tests' }\n" > "$work/ui/v.mod"

"$v" -new-compiler -nocache -gc none -manualfree -enable-globals -stats -d ui2_headless \
    -path "@vlib|@vmodules|$work/modules|$root|$root/third_party" "$work/ui/visual_test.v"
