#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

"${PROJECT_DIR}/Tests/BuildScriptTests/build-app-tests.sh"

TESTING_FRAMEWORK_DIRECTORY=""
for developer_directory in \
    "${DEVELOPER_DIR:-}" \
    "/Applications/Xcode.app/Contents/Developer" \
    "/Library/Developer/CommandLineTools"
do
    [[ -n "${developer_directory}" ]] || continue
    candidate="${developer_directory}/Library/Developer/Frameworks"
    if [[ -d "${candidate}/Testing.framework" ]]; then
        TESTING_FRAMEWORK_DIRECTORY="${candidate}"
        break
    fi
done

if [[ -z "${TESTING_FRAMEWORK_DIRECTORY}" ]]; then
    echo "error: Testing.framework not found in the configured Swift toolchains." >&2
    exit 1
fi

XUNIT_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-tests.XXXXXX")"
trap 'rm -rf "${XUNIT_DIRECTORY}"' EXIT
XUNIT_FILE="${XUNIT_DIRECTORY}/results.xml"

swift test \
    --package-path "${PROJECT_DIR}" \
    --disable-xctest \
    --enable-swift-testing \
    -Xswiftc -F \
    -Xswiftc "${TESTING_FRAMEWORK_DIRECTORY}" \
    --xunit-output "${XUNIT_FILE}"

if [[ ! -s "${XUNIT_FILE}" ]]; then
    echo "error: Swift Testing did not produce a non-empty xUnit report." >&2
    exit 1
fi

TEST_SUITE_LINE="$(sed -n '/<testsuite /{p;q;}' "${XUNIT_FILE}")"
read_attribute() {
    local name="$1"
    printf '%s\n' "${TEST_SUITE_LINE}" |
        sed -E "s/.* ${name}=\"([0-9]+)\".*/\\1/"
}

TEST_COUNT="$(read_attribute tests)"
ERROR_COUNT="$(read_attribute errors)"
FAILURE_COUNT="$(read_attribute failures)"

for value in "${TEST_COUNT}" "${ERROR_COUNT}" "${FAILURE_COUNT}"; do
    if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
        echo "error: malformed xUnit test summary: ${TEST_SUITE_LINE}" >&2
        exit 1
    fi
done

if (( TEST_COUNT == 0 )); then
    echo "error: Swift Testing reported zero executed tests." >&2
    exit 1
fi

if (( ERROR_COUNT != 0 || FAILURE_COUNT != 0 )); then
    echo "error: Swift Testing reported tests=${TEST_COUNT}, errors=${ERROR_COUNT}, failures=${FAILURE_COUNT}." >&2
    exit 1
fi

echo "Проверки пройдены: tests=${TEST_COUNT}, errors=${ERROR_COUNT}, failures=${FAILURE_COUNT}."
