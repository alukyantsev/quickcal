#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${PROJECT_DIR}/dist/QuickCal.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
RESOURCE_BUNDLE_NAME="QuickCal_QuickCalKit.bundle"
APP_ICON_NAME="QuickCal.icns"
APP_ICON_SOURCE="${PROJECT_DIR}/Support/${APP_ICON_NAME}"
MODERN_APP_ICON_NAME="Assets.car"
MODERN_APP_ICON_SOURCE="${PROJECT_DIR}/Support/${MODERN_APP_ICON_NAME}"

build_release() {
    swift build --package-path "${PROJECT_DIR}" -c release --arch arm64
}

probe_sdk() {
    local sdk_root="$1"

    SDKROOT="${sdk_root}" swiftc \
        -target arm64-apple-macosx14.0 \
        -sdk "${sdk_root}" \
        -typecheck "${PROBE_FILE}" \
        >/dev/null 2>&1
}

SELECTED_SDK_ROOT="${SDKROOT:-}"

if [[ -n "${SELECTED_SDK_ROOT}" ]]; then
    if [[ ! -d "${SELECTED_SDK_ROOT}" ]]; then
        echo "error: SDKROOT is not an existing directory: ${SELECTED_SDK_ROOT}" >&2
        exit 1
    fi

    SELECTED_SDK_ROOT="$(cd "${SELECTED_SDK_ROOT}" && pwd -P)"
    export SDKROOT="${SELECTED_SDK_ROOT}"
    build_release
else
    DEFAULT_SDK_ROOT="$(cd "$(xcrun --sdk macosx --show-sdk-path)" && pwd -P)"

    if build_release; then
        SELECTED_SDK_ROOT="${DEFAULT_SDK_ROOT}"
    else
        echo "Default SDK build failed; probing sibling macOS SDKs." >&2

        PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-sdk-probe.XXXXXX")"
        trap 'rm -rf "${PROBE_DIR}"' EXIT
        PROBE_FILE="${PROBE_DIR}/Probe.swift"
        printf 'import AppKit\n' > "${PROBE_FILE}"

        SDK_DIRECTORY="$(dirname "${DEFAULT_SDK_ROOT}")"
        while IFS= read -r candidate_sdk_root; do
            candidate_sdk_root="$(cd "${candidate_sdk_root}" && pwd -P)"
            [[ "${candidate_sdk_root}" == "${DEFAULT_SDK_ROOT}" ]] && continue

            if probe_sdk "${candidate_sdk_root}" && SDKROOT="${candidate_sdk_root}" build_release; then
                SELECTED_SDK_ROOT="${candidate_sdk_root}"
                break
            fi
        done < <(find "${SDK_DIRECTORY}" -maxdepth 1 -type d -name 'MacOSX*.sdk' -print | sort)

        if [[ -z "${SELECTED_SDK_ROOT}" ]]; then
            echo "error: no compatible macOS SDK found; set SDKROOT explicitly." >&2
            exit 1
        fi
    fi
fi

export SDKROOT="${SELECTED_SDK_ROOT}"
BIN_DIR="$(swift build --package-path "${PROJECT_DIR}" -c release --arch arm64 --show-bin-path)"
RESOURCE_BUNDLE_SOURCE="${BIN_DIR}/${RESOURCE_BUNDLE_NAME}"

if [[ ! -d "${RESOURCE_BUNDLE_SOURCE}" ]]; then
    echo "error: missing localization bundle: ${RESOURCE_BUNDLE_SOURCE}" >&2
    exit 1
fi

if [[ ! -f "${APP_ICON_SOURCE}" ]]; then
    echo "error: missing application icon: ${APP_ICON_SOURCE}" >&2
    exit 1
fi

if [[ ! -f "${MODERN_APP_ICON_SOURCE}" ]]; then
    echo "error: missing modern application icon: ${MODERN_APP_ICON_SOURCE}" >&2
    exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_DIR}/QuickCal" "${MACOS_DIR}/QuickCal"
cp "${PROJECT_DIR}/Support/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp -R "${RESOURCE_BUNDLE_SOURCE}" "${RESOURCES_DIR}/${RESOURCE_BUNDLE_NAME}"
cp "${APP_ICON_SOURCE}" "${RESOURCES_DIR}/${APP_ICON_NAME}"
cp "${MODERN_APP_ICON_SOURCE}" "${RESOURCES_DIR}/${MODERN_APP_ICON_NAME}"
chmod 755 "${MACOS_DIR}/QuickCal"

codesign --force --deep --sign - "${APP_DIR}"
plutil -lint "${CONTENTS_DIR}/Info.plist"
file "${MACOS_DIR}/QuickCal"
ARCHITECTURES="$(lipo -archs "${MACOS_DIR}/QuickCal")"
if [[ "${ARCHITECTURES}" != "arm64" ]]; then
    echo "error: expected arm64 binary, got: ${ARCHITECTURES}" >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "Готово: ${APP_DIR}"
