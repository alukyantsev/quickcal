#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-icon-tests.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT
OUTPUT_ICNS="${TEST_ROOT}/QuickCal.icns"
OUTPUT_ICONSET="${TEST_ROOT}/QuickCal.iconset"

"${PROJECT_DIR}/Scripts/generate-app-icon.sh" \
    "${PROJECT_DIR}/Support/QuickCalIcon-1024.png" \
    "${OUTPUT_ICNS}"

[[ -s "${OUTPUT_ICNS}" ]]
iconutil -c iconset "${OUTPUT_ICNS}" -o "${OUTPUT_ICONSET}"

for representation in \
    icon_16x16.png \
    icon_16x16@2x.png \
    icon_32x32.png \
    icon_32x32@2x.png \
    icon_128x128.png \
    icon_128x128@2x.png \
    icon_256x256.png \
    icon_256x256@2x.png \
    icon_512x512.png \
    icon_512x512@2x.png
do
    [[ -s "${OUTPUT_ICONSET}/${representation}" ]] || {
        echo "missing representation: ${representation}" >&2
        exit 1
    }
done

echo "ok - QuickCal.icns contains every required macOS representation"
