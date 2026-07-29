#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-build-script-tests.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

PROJECT_DIR="${TEST_ROOT}/QuickCal"
MOCK_BIN="${TEST_ROOT}/mock-bin"
SDK_ROOT="${TEST_ROOT}/MacOSX.sdk"
BIN_DIR="${TEST_ROOT}/release-bin"
RESOURCE_BUNDLE="${BIN_DIR}/QuickCal_QuickCalKit.bundle"
LOG_FILE="${TEST_ROOT}/commands.log"

mkdir -p \
    "${PROJECT_DIR}/Scripts" \
    "${PROJECT_DIR}/Support" \
    "${MOCK_BIN}" \
    "${SDK_ROOT}" \
    "${BIN_DIR}" \
    "${RESOURCE_BUNDLE}/en.lproj" \
    "${RESOURCE_BUNDLE}/ru.lproj"

SDK_ROOT="$(cd "${SDK_ROOT}" && pwd -P)"

cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/Scripts/build-app.sh" \
    "${PROJECT_DIR}/Scripts/build-app.sh"
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/Support/Info.plist" \
    "${PROJECT_DIR}/Support/Info.plist"
printf 'fixture executable\n' > "${BIN_DIR}/QuickCal"
printf 'fixture icon\n' > "${PROJECT_DIR}/Support/QuickCal.icns"
printf '"app.quit" = "Quit QuickCal";\n' \
    > "${RESOURCE_BUNDLE}/en.lproj/Localizable.strings"
printf '"app.quit" = "Выйти из QuickCal";\n' \
    > "${RESOURCE_BUNDLE}/ru.lproj/Localizable.strings"
chmod 755 "${BIN_DIR}/QuickCal"

write_mock() {
    local name="$1"
    shift
    printf '%s\n' "$@" > "${MOCK_BIN}/${name}"
    chmod 755 "${MOCK_BIN}/${name}"
}

write_mock swift \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "swift|%s|%s\n" "${SDKROOT:-}" "$*" >> "${QUICKCAL_TEST_LOG}"' \
    'if [[ " $* " == *" --show-bin-path "* ]]; then' \
    '    printf "%s\n" "${QUICKCAL_TEST_BIN_DIR}"' \
    'fi'

write_mock codesign \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "codesign|%s\n" "$*" >> "${QUICKCAL_TEST_LOG}"'

write_mock plutil \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "plutil|%s\n" "$*" >> "${QUICKCAL_TEST_LOG}"'

write_mock file \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "file|%s\n" "$*" >> "${QUICKCAL_TEST_LOG}"'

write_mock lipo \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "lipo|%s\n" "$*" >> "${QUICKCAL_TEST_LOG}"' \
    'printf "arm64\n"'

PATH="${MOCK_BIN}:${PATH}" \
SDKROOT="${SDK_ROOT}" \
QUICKCAL_TEST_LOG="${LOG_FILE}" \
QUICKCAL_TEST_BIN_DIR="${BIN_DIR}" \
    "${PROJECT_DIR}/Scripts/build-app.sh" >/dev/null

BUILD_COUNT="$(
    awk -F '|' -v sdk="${SDK_ROOT}" '
        $1 == "swift" && $2 == sdk && $3 ~ /^build / &&
        $3 !~ /--show-bin-path/ &&
        $3 ~ / -c release / &&
        $3 ~ / --arch arm64$/ {
            count += 1
        }
        END {
            print count + 0
        }
    ' "${LOG_FILE}"
)"

if [[ "${BUILD_COUNT}" != "1" ]]; then
    echo "not ok - explicit SDKROOT must perform one fresh arm64 release build" >&2
    echo "observed commands:" >&2
    sed 's/^/  /' "${LOG_FILE}" >&2
    exit 1
fi

echo "ok - explicit SDKROOT performs one fresh arm64 release build"

INSTALLED_RESOURCE_BUNDLE="$(
    printf '%s\n' \
        "${PROJECT_DIR}/dist/QuickCal.app/Contents/Resources/QuickCal_QuickCalKit.bundle"
)"

if ! cmp \
    "${RESOURCE_BUNDLE}/en.lproj/Localizable.strings" \
    "${INSTALLED_RESOURCE_BUNDLE}/en.lproj/Localizable.strings" >/dev/null
then
    echo "not ok - English localization must be copied into the app bundle" >&2
    exit 1
fi

if ! cmp \
    "${RESOURCE_BUNDLE}/ru.lproj/Localizable.strings" \
    "${INSTALLED_RESOURCE_BUNDLE}/ru.lproj/Localizable.strings" >/dev/null
then
    echo "not ok - Russian localization must be copied into the app bundle" >&2
    exit 1
fi

DEVELOPMENT_REGION="$(
    /usr/bin/plutil -extract CFBundleDevelopmentRegion raw \
        "${PROJECT_DIR}/dist/QuickCal.app/Contents/Info.plist"
)"
if [[ "${DEVELOPMENT_REGION}" != "en" ]]; then
    echo "not ok - English must be the app localization fallback" >&2
    exit 1
fi

FIRST_LOCALIZATION="$(
    /usr/bin/plutil -extract CFBundleLocalizations.0 raw \
        "${PROJECT_DIR}/dist/QuickCal.app/Contents/Info.plist"
)"
SECOND_LOCALIZATION="$(
    /usr/bin/plutil -extract CFBundleLocalizations.1 raw \
        "${PROJECT_DIR}/dist/QuickCal.app/Contents/Info.plist"
)"
if [[ "${FIRST_LOCALIZATION}" != "en" || "${SECOND_LOCALIZATION}" != "ru" ]]; then
    echo "not ok - the app must advertise English and Russian localizations" >&2
    exit 1
fi

INSTALLED_ICON="${PROJECT_DIR}/dist/QuickCal.app/Contents/Resources/QuickCal.icns"
cmp "${PROJECT_DIR}/Support/QuickCal.icns" "${INSTALLED_ICON}" >/dev/null || {
    echo "not ok - QuickCal.icns must be copied into the app bundle" >&2
    exit 1
}

ICON_FILE="$(
    /usr/bin/plutil -extract CFBundleIconFile raw \
        "${PROJECT_DIR}/dist/QuickCal.app/Contents/Info.plist"
)"
if [[ "${ICON_FILE}" != "QuickCal.icns" ]]; then
    echo "not ok - CFBundleIconFile must reference QuickCal.icns" >&2
    exit 1
fi

mv "${PROJECT_DIR}/Support/QuickCal.icns" "${TEST_ROOT}/missing-QuickCal.icns"
MISSING_ICON_ERROR="${TEST_ROOT}/missing-icon-error.log"

if PATH="${MOCK_BIN}:${PATH}" \
    SDKROOT="${SDK_ROOT}" \
    QUICKCAL_TEST_LOG="${LOG_FILE}" \
    QUICKCAL_TEST_BIN_DIR="${BIN_DIR}" \
        "${PROJECT_DIR}/Scripts/build-app.sh" \
        >"${TEST_ROOT}/missing-icon-output.log" \
        2>"${MISSING_ICON_ERROR}"
then
    echo "not ok - a missing application icon must fail the build" >&2
    exit 1
fi

if [[ "$(<"${MISSING_ICON_ERROR}")" != *"missing application icon"* ]]; then
    echo "not ok - missing icon failure must be actionable" >&2
    exit 1
fi

mv "${TEST_ROOT}/missing-QuickCal.icns" \
    "${PROJECT_DIR}/Support/QuickCal.icns"

mv "${RESOURCE_BUNDLE}" "${TEST_ROOT}/missing-resource-bundle"
MISSING_RESOURCE_ERROR="${TEST_ROOT}/missing-resource-error.log"

if PATH="${MOCK_BIN}:${PATH}" \
    SDKROOT="${SDK_ROOT}" \
    QUICKCAL_TEST_LOG="${LOG_FILE}" \
    QUICKCAL_TEST_BIN_DIR="${BIN_DIR}" \
        "${PROJECT_DIR}/Scripts/build-app.sh" \
        >"${TEST_ROOT}/missing-resource-output.log" \
        2>"${MISSING_RESOURCE_ERROR}"
then
    echo "not ok - a missing localization bundle must fail the build" >&2
    exit 1
fi

if [[ "$(<"${MISSING_RESOURCE_ERROR}")" != *"missing localization bundle"* ]]; then
    echo "not ok - missing localization failure must be actionable" >&2
    exit 1
fi

echo "ok - localization resources are packaged with fail-fast validation"
echo "ok - QuickCal.icns is packaged with fail-fast validation"
