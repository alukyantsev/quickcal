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
if ! iconutil -c icns "${ICONSET_DIRECTORY}" -o "${OUTPUT_ICNS}" >/dev/null 2>&1; then
    # macOS 26.5's iconutil rejects even iconsets that it just extracted from
    # a system .icns. Serialize the documented PNG-backed ICNS chunks from the
    # same rendered representations so the public interface remains stable.
    python3 - "${ICONSET_DIRECTORY}" "${OUTPUT_ICNS}" <<'PY'
import struct
import sys
from pathlib import Path

iconset = Path(sys.argv[1])
output = Path(sys.argv[2])
representations = (
    (b"icp4", "icon_16x16.png"),
    (b"ic11", "icon_16x16@2x.png"),
    (b"icp5", "icon_32x32.png"),
    (b"ic12", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic13", "icon_128x128@2x.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic14", "icon_256x256@2x.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
)

chunks = []
for chunk_type, filename in representations:
    image = (iconset / filename).read_bytes()
    chunks.append(chunk_type + struct.pack(">I", len(image) + 8) + image)

payload = b"".join(chunks)
output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
PY
fi
echo "Готово: ${OUTPUT_ICNS}"
