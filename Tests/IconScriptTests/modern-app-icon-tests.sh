#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-modern-icon-tests.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

FIXTURE_PROJECT="${TEST_ROOT}/QuickCal"
MOCK_BIN="${TEST_ROOT}/mock-bin"
LOG_FILE="${TEST_ROOT}/actool.log"

mkdir -p \
    "${FIXTURE_PROJECT}/Scripts" \
    "${FIXTURE_PROJECT}/Support/AppIcon.icon/Assets" \
    "${MOCK_BIN}"

FIXTURE_PROJECT="$(cd "${FIXTURE_PROJECT}" && pwd -P)"
OUTPUT_CAR="${FIXTURE_PROJECT}/Support/Assets.car"

cp "${PROJECT_DIR}/Scripts/generate-modern-app-icon.sh" \
    "${FIXTURE_PROJECT}/Scripts/generate-modern-app-icon.sh"
cp "${PROJECT_DIR}/Support/AppIcon.icon/icon.json" \
    "${FIXTURE_PROJECT}/Support/AppIcon.icon/icon.json"
cp "${PROJECT_DIR}/Support/AppIcon.icon/Assets/QuickCalIcon-1024.png" \
    "${FIXTURE_PROJECT}/Support/AppIcon.icon/Assets/QuickCalIcon-1024.png"

cat > "${MOCK_BIN}/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "--find actool" ]]; then
    printf '%s\n' "${QUICKCAL_TEST_ACTOOL}"
    exit 0
fi

echo "unexpected xcrun invocation: $*" >&2
exit 1
EOF
chmod 755 "${MOCK_BIN}/xcrun"

cat > "${MOCK_BIN}/actool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "${QUICKCAL_TEST_LOG}"

compile_directory=""
while (( $# > 0 )); do
    if [[ "$1" == "--compile" ]]; then
        compile_directory="$2"
        break
    fi
    shift
done

[[ -n "${compile_directory}" ]] || {
    echo "mock actool did not receive --compile" >&2
    exit 1
}

mkdir -p "${compile_directory}"
printf 'compiled QuickCal AppIcon\n' > "${compile_directory}/Assets.car"
EOF
chmod 755 "${MOCK_BIN}/actool"

PATH="${MOCK_BIN}:${PATH}" \
QUICKCAL_TEST_ACTOOL="${MOCK_BIN}/actool" \
QUICKCAL_TEST_LOG="${LOG_FILE}" \
    "${FIXTURE_PROJECT}/Scripts/generate-modern-app-icon.sh"

EXPECTED_CAR="${TEST_ROOT}/expected-Assets.car"
printf 'compiled QuickCal AppIcon\n' > "${EXPECTED_CAR}"
cmp "${EXPECTED_CAR}" "${OUTPUT_CAR}" >/dev/null || {
    echo "not ok - generator must publish the Assets.car produced by actool" >&2
    exit 1
}

ACTOOL_ARGUMENTS="$(<"${LOG_FILE}")"
for required_argument in \
    "${FIXTURE_PROJECT}/Support/AppIcon.icon" \
    "--compile" \
    "--platform macosx" \
    "--minimum-deployment-target 14.0" \
    "--app-icon AppIcon"
do
    if [[ "${ACTOOL_ARGUMENTS}" != *"${required_argument}"* ]]; then
        echo "not ok - actool invocation is missing: ${required_argument}" >&2
        echo "observed arguments: ${ACTOOL_ARGUMENTS}" >&2
        exit 1
    fi
done

echo "ok - modern icon generator publishes the AppIcon Assets.car produced by actool"

mv "${MOCK_BIN}/actool" "${TEST_ROOT}/missing-actool"
MISSING_ACTOOL_ERROR="${TEST_ROOT}/missing-actool-error.log"

if PATH="${MOCK_BIN}:${PATH}" \
    QUICKCAL_TEST_ACTOOL="${MOCK_BIN}/actool" \
    QUICKCAL_TEST_LOG="${LOG_FILE}" \
        "${FIXTURE_PROJECT}/Scripts/generate-modern-app-icon.sh" \
        >"${TEST_ROOT}/missing-actool-output.log" \
        2>"${MISSING_ACTOOL_ERROR}"
then
    echo "not ok - missing actool must fail modern icon generation" >&2
    exit 1
fi

if [[ "$(<"${MISSING_ACTOOL_ERROR}")" != *"actool"* ]]; then
    echo "not ok - missing actool failure must be actionable" >&2
    exit 1
fi

echo "ok - modern icon generator fails clearly when actool is unavailable"
