#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${PROJECT_DIR}/dist/QuickCal.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Some Command Line Tools installations expose a default SDK built by an older
# Swift compiler. Prefer the locally installed macOS 15.4 SDK when available;
# callers can override this selection with SDKROOT.
if [[ -z "${SDKROOT:-}" ]]; then
    DEFAULT_SDK_ROOT="$(xcrun --sdk macosx --show-sdk-path)"
    COMPATIBLE_SDK_ROOT="$(dirname "${DEFAULT_SDK_ROOT}")/MacOSX15.4.sdk"
    export SDKROOT="${COMPATIBLE_SDK_ROOT}"
    if [[ ! -d "${SDKROOT}" ]]; then
        export SDKROOT="${DEFAULT_SDK_ROOT}"
    fi
fi

swift build --package-path "${PROJECT_DIR}" -c release --arch arm64
BIN_DIR="$(swift build --package-path "${PROJECT_DIR}" -c release --arch arm64 --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
cp "${BIN_DIR}/QuickCal" "${MACOS_DIR}/QuickCal"
cp "${PROJECT_DIR}/Support/Info.plist" "${CONTENTS_DIR}/Info.plist"
chmod 755 "${MACOS_DIR}/QuickCal"

codesign --force --deep --sign - "${APP_DIR}"
plutil -lint "${CONTENTS_DIR}/Info.plist"
file "${MACOS_DIR}/QuickCal"
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "Готово: ${APP_DIR}"
