#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-build-script-tests.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

PROJECT_DIR="${TEST_ROOT}/QuickCal"
MOCK_BIN="${TEST_ROOT}/mock-bin"
SDK_ROOT="${TEST_ROOT}/MacOSX.sdk"
BIN_DIR="${TEST_ROOT}/release-bin"
LOG_FILE="${TEST_ROOT}/commands.log"

mkdir -p \
    "${PROJECT_DIR}/Scripts" \
    "${PROJECT_DIR}/Support" \
    "${MOCK_BIN}" \
    "${SDK_ROOT}" \
    "${BIN_DIR}"

SDK_ROOT="$(cd "${SDK_ROOT}" && pwd -P)"

cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/Scripts/build-app.sh" \
    "${PROJECT_DIR}/Scripts/build-app.sh"
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/Support/Info.plist" \
    "${PROJECT_DIR}/Support/Info.plist"
printf 'fixture executable\n' > "${BIN_DIR}/QuickCal"
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
