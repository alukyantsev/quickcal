#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_ICON="${1:-${PROJECT_DIR}/Support/AppIcon.icon}"
OUTPUT_CAR="${2:-${PROJECT_DIR}/Support/Assets.car}"

if [[ ! -f "${SOURCE_ICON}/icon.json" ]]; then
    echo "error: missing Icon Composer source: ${SOURCE_ICON}/icon.json" >&2
    exit 1
fi

if [[ ! -f "${SOURCE_ICON}/Assets/QuickCalIcon-1024.png" ]]; then
    echo "error: missing Icon Composer image: ${SOURCE_ICON}/Assets/QuickCalIcon-1024.png" >&2
    exit 1
fi

ACTOOL="$(xcrun --find actool 2>/dev/null || true)"
if [[ -z "${ACTOOL}" || ! -x "${ACTOOL}" ]]; then
    echo "error: actool is unavailable; install full Xcode and select its Developer directory." >&2
    exit 1
fi

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-modern-icon.XXXXXX")"
trap 'rm -rf "${TEMP_DIRECTORY}"' EXIT
COMPILED_DIRECTORY="${TEMP_DIRECTORY}/compiled"
PARTIAL_INFO_PLIST="${TEMP_DIRECTORY}/asset-info.plist"
mkdir -p "${COMPILED_DIRECTORY}"

"${ACTOOL}" \
    "${SOURCE_ICON}" \
    --compile "${COMPILED_DIRECTORY}" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "${PARTIAL_INFO_PLIST}"

COMPILED_CAR="${COMPILED_DIRECTORY}/Assets.car"
if [[ ! -s "${COMPILED_CAR}" ]]; then
    echo "error: actool did not produce Assets.car for AppIcon." >&2
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT_CAR}")"
cp "${COMPILED_CAR}" "${OUTPUT_CAR}"
echo "Готово: ${OUTPUT_CAR}"
