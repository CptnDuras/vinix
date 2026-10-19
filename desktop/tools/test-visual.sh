#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Runs the Blue programmatic visual UI-surface test: renders each look to a
# canvas and asserts signature pixels. Set VINIX_SNAPSHOT_DIR to also dump a PNG
# per look. Staged like test-settings.sh (needs V and third_party/ui2).
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
v=${V:-v}
command -v "$v" >/dev/null 2>&1 || { echo 'ERROR: V is required.' >&2; exit 1; }
[ -f "$root/third_party/ui2/v.mod" ] || {
    echo 'ERROR: visual tests require third_party/ui2.' >&2; exit 1;
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
# The installed skins, as the image has them, so the Glass skin's PNG art is read
# from files.
"$root/desktop/tools/build_skins" "$root/desktop/skins" "$work/skins"
export VINIX_SKIN_DIR="$work/skins"
"$root/desktop/tools/stage_ui2" \
    "$work/modules/ui2" "$root/third_party/ui2" \
    "$root/desktop/tools/ui2_headless_bounds.v"
mkdir "$work/ui"
"$root/desktop/tools/stage_app" "$work/ui" "$root/desktop" \
    "$root/third_party/ui2/examples/calculator" >/dev/null
"$root/desktop/tools/stage_host_gpu" "$work/ui" --v "$v"
"$root/build-support/run-v-tool.sh" "$root/desktop/tools/native-utility-source.v" materialize "$work/ui"
rm -f "$work/ui/main.v"
cp "$root/desktop/tools/tests/visual_test.v" "$work/ui/"
printf "Module { name: 'visual_tests' }\n" > "$work/ui/v.mod"

"$v" -new-compiler -nocache -gc none -manualfree -enable-globals -stats -d ui2_headless \
    -path "@vlib|@vmodules|$work/modules|$root|$root/third_party" "$work/ui/visual_test.v"
