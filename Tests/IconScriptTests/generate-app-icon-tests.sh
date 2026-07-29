#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-icon-tests.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT
OUTPUT_ICNS="${TEST_ROOT}/QuickCal.icns"
OUTPUT_ICONSET="${TEST_ROOT}/QuickCal.iconset"
FALLBACK_ICNS="${TEST_ROOT}/QuickCal-fallback.icns"
FALLBACK_ICONSET="${TEST_ROOT}/QuickCal-fallback.iconset"

assert_representations() {
    local icns_path="$1"
    local iconset_path="$2"

    [[ -s "${icns_path}" ]]
    iconutil -c iconset "${icns_path}" -o "${iconset_path}"

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
        [[ -s "${iconset_path}/${representation}" ]] || {
            echo "missing representation: ${representation}" >&2
            exit 1
        }
    done
}

"${PROJECT_DIR}/Scripts/generate-app-icon.sh" \
    "${PROJECT_DIR}/Support/QuickCalIcon-1024.png" \
    "${OUTPUT_ICNS}"
assert_representations "${OUTPUT_ICNS}" "${OUTPUT_ICONSET}"

fallback_output="$(
    QUICKCAL_FORCE_RAW_ICNS_FALLBACK=1 \
        "${PROJECT_DIR}/Scripts/generate-app-icon.sh" \
        "${PROJECT_DIR}/Support/QuickCalIcon-1024.png" \
        "${FALLBACK_ICNS}" 2>&1
)"
printf '%s\n' "${fallback_output}"
[[ "${fallback_output}" == *"Использован raw ICNS fallback" ]]
assert_representations "${FALLBACK_ICNS}" "${FALLBACK_ICONSET}"

echo "ok - QuickCal.icns and forced raw fallback contain every required macOS representation"
