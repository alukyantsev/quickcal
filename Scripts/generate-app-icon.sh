#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PNG="${1:-${PROJECT_DIR}/Support/QuickCalIcon-1024.png}"
OUTPUT_ICNS="${2:-${PROJECT_DIR}/Support/QuickCal.icns}"

[[ -f "${SOURCE_PNG}" ]] || {
    echo "error: missing app icon master: ${SOURCE_PNG}" >&2
    exit 1
}

PIXEL_WIDTH="$(sips -g pixelWidth "${SOURCE_PNG}" | awk '/pixelWidth/{print $2}')"
PIXEL_HEIGHT="$(sips -g pixelHeight "${SOURCE_PNG}" | awk '/pixelHeight/{print $2}')"
if [[ "${PIXEL_WIDTH}" != "1024" || "${PIXEL_HEIGHT}" != "1024" ]]; then
    echo "error: app icon master must be 1024x1024, got ${PIXEL_WIDTH}x${PIXEL_HEIGHT}" >&2
    exit 1
fi

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-iconset.XXXXXX")"
trap 'rm -rf "${TEMP_DIRECTORY}"' EXIT
ICONSET_DIRECTORY="${TEMP_DIRECTORY}/QuickCal.iconset"
mkdir -p "${ICONSET_DIRECTORY}"

render() {
    local pixels="$1"
    local filename="$2"
    sips -z "${pixels}" "${pixels}" "${SOURCE_PNG}" \
        --out "${ICONSET_DIRECTORY}/${filename}" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

mkdir -p "$(dirname "${OUTPUT_ICNS}")"
RAW_CHUNK_TYPES=(
    icp4 ic11 icp5 ic12 ic07 ic13 ic08 ic14 ic09 ic10
)
RAW_FILENAMES=(
    icon_16x16.png icon_16x16@2x.png icon_32x32.png icon_32x32@2x.png
    icon_128x128.png icon_128x128@2x.png icon_256x256.png icon_256x256@2x.png
    icon_512x512.png icon_512x512@2x.png
)

write_u32_be() {
    local value="$1"
    local byte
    local shift

    for shift in 24 16 8 0; do
        byte=$(( (value >> shift) & 255 ))
        printf "\\$(printf '%03o' "${byte}")"
    done
}

serialize_raw_icns() {
    local total_size=8
    local index
    local image_size
    local image_path

    for index in "${!RAW_FILENAMES[@]}"; do
        image_path="${ICONSET_DIRECTORY}/${RAW_FILENAMES[${index}]}"
        image_size="$(wc -c < "${image_path}")"
        total_size=$((total_size + image_size + 8))
    done

    {
        printf 'icns'
        write_u32_be "${total_size}"

        for index in "${!RAW_FILENAMES[@]}"; do
            image_path="${ICONSET_DIRECTORY}/${RAW_FILENAMES[${index}]}"
            image_size="$(wc -c < "${image_path}")"
            printf '%s' "${RAW_CHUNK_TYPES[${index}]}"
            write_u32_be "$((image_size + 8))"
            cat "${image_path}"
        done
    } > "${OUTPUT_ICNS}"

    echo "Использован raw ICNS fallback" >&2
}

# macOS 26.5's iconutil rejects even iconsets that it just extracted from a
# system .icns. Keep this serializer to Bash and POSIX utilities so that the
# fallback has no interpreter dependency. The environment switch is test-only.
if [[ "${QUICKCAL_FORCE_RAW_ICNS_FALLBACK:-0}" == "1" ]]; then
    serialize_raw_icns
elif ! iconutil -c icns "${ICONSET_DIRECTORY}" -o "${OUTPUT_ICNS}" >/dev/null 2>&1; then
    serialize_raw_icns
fi
echo "Готово: ${OUTPUT_ICNS}"
