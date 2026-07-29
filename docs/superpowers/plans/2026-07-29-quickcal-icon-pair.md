# QuickCal Icon Pair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить menu bar grid на `calendar.badge.clock` и добавить коррелирующую синюю иконку QuickCal для Finder.

**Architecture:** Menu bar продолжает использовать собственный `NSStatusItem`, но получает новый template SF Symbol. Finder-иконка хранится как проверенный мастер 1024×1024 и производный `QuickCal.icns`; release-сборка копирует `.icns` в bundle и завершается ошибкой при отсутствии ресурса.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SF Symbols, Bash, `sips`, `iconutil`, Swift Testing, macOS 14.

## Global Constraints

- Приложение остаётся локальным, arm64-only, для macOS 14+ и Apple Silicon.
- Menu bar icon остаётся монохромным template image и следует светлой/тёмной теме macOS.
- Finder-иконка статично синяя; системный accent color продолжает применяться только к интерактивным элементам QuickCal.
- Основной знак — календарь и clock badge справа снизу; без текста, буквы `Q` и номера дня.
- Целевая оптическая высота menu bar icon — не менее 95% от 17-point reference ChatGPT.
- Сборка обязана завершаться ошибкой, если `QuickCal.icns` отсутствует.
- Публикация в App Store и альтернативные theme-specific app icons вне scope.

---

## File Map

- `Support/QuickCalIcon-1024.png` — утверждённый мастер Finder-иконки.
- `Support/QuickCal.icns` — производный ресурс для app bundle.
- `Scripts/generate-app-icon.sh` — воспроизводимо строит `.icns` из master PNG.
- `Tests/IconScriptTests/generate-app-icon-tests.sh` — проверяет размеры и состав `.icns`.
- `Scripts/build-app.sh` — fail-fast проверка и копирование `.icns`.
- `Tests/BuildScriptTests/build-app-tests.sh` — контракт packaging и missing-icon failure.
- `Support/Info.plist` — `CFBundleIconFile = QuickCal.icns`.
- `Sources/QuickCal/QuickCalApp.swift` — SF Symbol `calendar.badge.clock`.
- `Tests/RuntimeTests/menu-bar-icon-size.sh` — оптическая runtime-проверка.
- `.gitignore` — исключает временный `.superpowers/`.
- `docs/verification-calendar-enhancements.md` — итоговые факты и evidence.

---

### Task 1: Finder icon master and deterministic `.icns`

**Files:**
- Create: `Support/QuickCalIcon-1024.png`
- Create: `Support/QuickCal.icns`
- Create: `Scripts/generate-app-icon.sh`
- Create: `Tests/IconScriptTests/generate-app-icon-tests.sh`

**Interfaces:**
- Consumes: утверждённый дизайн «календарь + часы», PNG ровно 1024×1024.
- Produces: `Scripts/generate-app-icon.sh [source_png] [output_icns]` и `Support/QuickCal.icns`.

- [ ] **Step 1: Создать мастер через image generation**

Использовать approved design и следующий prompt без добавления текста:

```text
Create a polished macOS application icon for “QuickCal”, square 1024×1024.
Use a standard modern macOS rounded-square/squircle silhouette with transparent
outside corners. Background: soft cyan in the upper-left transitioning to
system blue and deep blue in the lower-right. Center a clean white calendar
with two top binding tabs and a small grid. Add a circular clock badge at the
calendar’s lower-right corner, with a white face and blue hands. Use subtle
macOS-like depth, inner highlight and soft shadow, not photorealistic. No text,
no letter Q, no date number, no extra objects, no border around the full icon.
Keep the calendar and clock readable at 16×16.
```

Сохранить результат как `Support/QuickCalIcon-1024.png` и визуально проверить:

- ровно один календарь;
- ровно один clock badge;
- нет текста и лишних символов;
- badge не касается края squircle;
- основной знак читается при уменьшении до 32×32.

- [ ] **Step 2: Написать сначала failing icon-generation test**

Создать `Tests/IconScriptTests/generate-app-icon-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-icon-tests.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT
OUTPUT_ICNS="${TEST_ROOT}/QuickCal.icns"
OUTPUT_ICONSET="${TEST_ROOT}/QuickCal.iconset"

"${PROJECT_DIR}/Scripts/generate-app-icon.sh" \
    "${PROJECT_DIR}/Support/QuickCalIcon-1024.png" \
    "${OUTPUT_ICNS}"

[[ -s "${OUTPUT_ICNS}" ]]
iconutil -c iconset "${OUTPUT_ICNS}" -o "${OUTPUT_ICONSET}"

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
    [[ -s "${OUTPUT_ICONSET}/${representation}" ]] || {
        echo "missing representation: ${representation}" >&2
        exit 1
    }
done

echo "ok - QuickCal.icns contains every required macOS representation"
```

- [ ] **Step 3: Запустить test и подтвердить RED**

Run:

```bash
chmod +x Tests/IconScriptTests/generate-app-icon-tests.sh
Tests/IconScriptTests/generate-app-icon-tests.sh
```

Expected: FAIL с `Scripts/generate-app-icon.sh: No such file or directory`.

- [ ] **Step 4: Реализовать генератор**

Создать `Scripts/generate-app-icon.sh`:

```bash
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
iconutil -c icns "${ICONSET_DIRECTORY}" -o "${OUTPUT_ICNS}"
echo "Готово: ${OUTPUT_ICNS}"
```

- [ ] **Step 5: Подтвердить GREEN и создать канонический `.icns`**

Run:

```bash
chmod +x Scripts/generate-app-icon.sh
Tests/IconScriptTests/generate-app-icon-tests.sh
Scripts/generate-app-icon.sh
```

Expected:

```text
ok - QuickCal.icns contains every required macOS representation
Готово: .../Support/QuickCal.icns
```

- [ ] **Step 6: Проверить smallest representations**

Run:

```bash
TEMP_ICONSET="$(mktemp -d "${TMPDIR:-/tmp}/quickcal-review.XXXXXX")"
iconutil -c iconset Support/QuickCal.icns -o "${TEMP_ICONSET}/QuickCal.iconset"
sips -g pixelWidth -g pixelHeight \
    "${TEMP_ICONSET}/QuickCal.iconset/icon_16x16.png" \
    "${TEMP_ICONSET}/QuickCal.iconset/icon_512x512@2x.png"
```

Expected: `16×16` и `1024×1024`; визуально календарь и badge различимы в
16×16 и 32×32.

- [ ] **Step 7: Commit**

```bash
git add \
    Support/QuickCalIcon-1024.png \
    Support/QuickCal.icns \
    Scripts/generate-app-icon.sh \
    Tests/IconScriptTests/generate-app-icon-tests.sh
git commit -m "feat: add QuickCal application icon assets"
```

---

### Task 2: Package Finder icon into `QuickCal.app`

**Files:**
- Modify: `Tests/BuildScriptTests/build-app-tests.sh`
- Modify: `Scripts/build-app.sh`
- Modify: `Support/Info.plist`

**Interfaces:**
- Consumes: `Support/QuickCal.icns` from Task 1.
- Produces: `QuickCal.app/Contents/Resources/QuickCal.icns` and `CFBundleIconFile`.

- [ ] **Step 1: Добавить failing packaging assertions**

В test fixture до вызова `build-app.sh` создать icon fixture:

```bash
printf 'fixture icon\n' > "${PROJECT_DIR}/Support/QuickCal.icns"
```

После успешной сборки добавить:

```bash
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
```

Перед существующим блоком, который перемещает `RESOURCE_BUNDLE` для
missing-localization test, добавить missing-icon contract:

```bash
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
```

Иконка восстанавливается до missing-localization test, поэтому две fail-fast
ветки проверяются независимо и не маскируют друг друга.

- [ ] **Step 2: Запустить test и подтвердить RED**

Run:

```bash
Tests/BuildScriptTests/build-app-tests.sh
```

Expected: FAIL на отсутствии bundled `QuickCal.icns` или
`CFBundleIconFile`.

- [ ] **Step 3: Реализовать fail-fast packaging**

В `Scripts/build-app.sh` рядом с resource bundle constants добавить:

```bash
APP_ICON_NAME="QuickCal.icns"
APP_ICON_SOURCE="${PROJECT_DIR}/Support/${APP_ICON_NAME}"
```

До очистки `APP_DIR` добавить:

```bash
if [[ ! -f "${APP_ICON_SOURCE}" ]]; then
    echo "error: missing application icon: ${APP_ICON_SOURCE}" >&2
    exit 1
fi
```

После копирования localization bundle добавить:

```bash
cp "${APP_ICON_SOURCE}" "${RESOURCES_DIR}/${APP_ICON_NAME}"
```

В `Support/Info.plist` добавить:

```xml
<key>CFBundleIconFile</key>
<string>QuickCal.icns</string>
```

- [ ] **Step 4: Запустить packaging test и подтвердить GREEN**

Run:

```bash
Tests/BuildScriptTests/build-app-tests.sh
```

Expected:

```text
ok - QuickCal.icns is packaged with fail-fast validation
```

Если test сохраняет старые success messages, добавить отдельный итоговый
message с этой точной формулировкой.

- [ ] **Step 5: Запустить полный test suite**

Run:

```bash
./Scripts/test.sh
```

Expected: 0 errors, 0 failures и ненулевое число тестов.

- [ ] **Step 6: Commit**

```bash
git add \
    Tests/BuildScriptTests/build-app-tests.sh \
    Scripts/build-app.sh \
    Support/Info.plist
git commit -m "feat: package QuickCal Finder icon"
```

---

### Task 3: Correlated menu bar symbol

**Files:**
- Modify: `Sources/QuickCal/QuickCalApp.swift:32-40`
- Test: `Tests/RuntimeTests/menu-bar-icon-size.sh`
- Create: `docs/evidence/quickcal-menu-icon-clock.png`

**Interfaces:**
- Consumes: macOS 14 SF Symbol `calendar.badge.clock`.
- Produces: template status icon с календарём и clock badge.

- [ ] **Step 1: Зафиксировать текущий acceptance failure**

Текущая сборка использует:

```swift
systemSymbolName: "calendar"
```

Это и есть зафиксированная пользовательская acceptance failure: символ
выглядит как простая grid и не коррелирует с Finder-иконкой.

Проверить доступность нового symbol:

```bash
swift -e '
import AppKit
precondition(
    NSImage(
        systemSymbolName: "calendar.badge.clock",
        accessibilityDescription: "QuickCal"
    ) != nil
)
print("ok - calendar.badge.clock is available")
'
```

Expected: `ok - calendar.badge.clock is available`.

- [ ] **Step 2: Выполнить минимальную production-правку**

В `Sources/QuickCal/QuickCalApp.swift` заменить только symbol name:

```swift
let image = NSImage(
    systemSymbolName: "calendar.badge.clock",
    accessibilityDescription: "QuickCal"
)?.withSymbolConfiguration(symbolConfiguration)
```

Сохранить `pointSize: 18`, `weight: .medium`, template mode и
`imageScaling = .scaleNone` до runtime-измерения.

- [ ] **Step 3: Собрать и установить**

Run:

```bash
./Scripts/build-app.sh
osascript -e 'tell application id "local.andrei.quickcal" to quit' 2>/dev/null || true
/usr/bin/ditto dist/QuickCal.app /Applications/QuickCal.app
open /Applications/QuickCal.app
```

Expected: arm64 bundle, valid signature, запущенный процесс.

- [ ] **Step 4: Проверить оптический размер**

Run:

```bash
Tests/RuntimeTests/menu-bar-icon-size.sh
```

Expected: `ratio >= 0.950` относительно ChatGPT reference 17 pt.

Если symbol выходит за 24-point menu bar или ratio ниже `0.950`, изменить
только `pointSize` и повторять сборку/измерение. Не менять weight и
композицию без нового согласования.

- [ ] **Step 5: Проверить popover regression**

Через macOS Accessibility:

1. кликнуть status item;
2. подтвердить открытие `NSPopover`;
3. выключить `Show week numbers`;
4. подтвердить ширину 310 pt вместо 342 pt;
5. вернуть настройку во включённое состояние;
6. закрыть popover.

- [ ] **Step 6: Сохранить visual evidence**

Снять только область status item и сохранить:

```text
docs/evidence/quickcal-menu-icon-clock.png
```

На изображении должны читаться календарь и clock badge; unrelated desktop
content не включать.

- [ ] **Step 7: Commit**

```bash
git add \
    Sources/QuickCal/QuickCalApp.swift \
    docs/evidence/quickcal-menu-icon-clock.png
git commit -m "feat: use QuickCal clock badge menu icon"
```

---

### Task 4: Final bundle acceptance and documentation

**Files:**
- Modify: `.gitignore`
- Modify: `docs/verification-calendar-enhancements.md`
- Create: `docs/evidence/quickcal-finder-icon.png`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: установленная проверенная `/Applications/QuickCal.app` и
  воспроизводимые verification facts.

- [ ] **Step 1: Исключить visual companion state**

Добавить в `.gitignore`:

```text
.superpowers/
```

Убедиться, что `git status --short` больше не показывает временную visual
session.

- [ ] **Step 2: Выполнить полный verification**

Run:

```bash
./Scripts/test.sh
./Scripts/build-app.sh
```

Expected:

- 0 test errors/failures;
- `Mach-O 64-bit executable arm64`;
- `QuickCal.app: valid on disk`;
- `QuickCal.app: satisfies its Designated Requirement`.

- [ ] **Step 3: Проверить icon bundle contract**

Run:

```bash
test -s dist/QuickCal.app/Contents/Resources/QuickCal.icns
test "$(
    /usr/bin/plutil -extract CFBundleIconFile raw \
        dist/QuickCal.app/Contents/Info.plist
)" = "QuickCal.icns"
```

Expected: exit 0.

- [ ] **Step 4: Установить финальный bundle и обновить LaunchServices**

Run:

```bash
osascript -e 'tell application id "local.andrei.quickcal" to quit' 2>/dev/null || true
/usr/bin/ditto dist/QuickCal.app /Applications/QuickCal.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f /Applications/QuickCal.app
open /Applications/QuickCal.app
```

- [ ] **Step 5: Подтвердить Finder icon**

Получить resolved icon через `NSWorkspace.shared.icon(forFile:)`, сохранить
PNG evidence и визуально подтвердить:

- синий squircle;
- белый календарь;
- clock badge справа снизу;
- отсутствие generic executable/grid icon.

Сохранить evidence:

```text
docs/evidence/quickcal-finder-icon.png
```

- [ ] **Step 6: Проверить установленный бинарник**

Run:

```bash
shasum -a 256 \
    dist/QuickCal.app/Contents/MacOS/QuickCal \
    /Applications/QuickCal.app/Contents/MacOS/QuickCal
file /Applications/QuickCal.app/Contents/MacOS/QuickCal
codesign --verify --deep --strict --verbose=2 /Applications/QuickCal.app
pgrep -fl '/Applications/QuickCal.app/Contents/MacOS/QuickCal'
```

Expected: hashes совпадают, `arm64`, valid signature, один запущенный process.

- [ ] **Step 7: Обновить verification document**

В `docs/verification-calendar-enhancements.md` заменить старые icon facts:

- menu bar symbol `calendar.badge.clock`;
- фактический optical bbox/ratio;
- `QuickCal.icns` и `CFBundleIconFile`;
- resolved Finder icon evidence;
- новый executable SHA-256.

- [ ] **Step 8: Final commit**

```bash
git add \
    .gitignore \
    docs/verification-calendar-enhancements.md \
    docs/evidence/quickcal-finder-icon.png
git commit -m "test: verify QuickCal icon pair"
```

- [ ] **Step 9: Final clean-state check**

Run:

```bash
git diff --check
git status --short --branch
```

Expected: clean `feature/quickcal-calendar-enhancements`.
