# QuickCal Six Themes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Реализовать в QuickCal шесть утверждённых тем, системный стартовый выбор и сохранённое циклическое переключение кнопкой `paintpalette`.

**Architecture:** Тестируемая модель порядка и сохранения тем размещается в `QuickCalKit`. SwiftUI executable преобразует выбранную модель в цветовые и геометрические токены, применяет их через environment ко всем существующим компонентам и синхронизирует Light/Dark с `NSPopover`.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Combine, Swift Testing, UserDefaults, SF Symbols, macOS 14+.

## Global Constraints

- Сохранить поддержку macOS 14+, Apple Silicon и существующие зависимости.
- Не менять поведение календаря, производственного календаря, выбранных дат и автозапуска.
- Не дублировать видимую надпись `Сегодня`.
- Использовать SF Symbol `paintpalette` и локализованную подпись `Следующая тема` / `Next theme`.
- Порядок: System Light → System Dark → Swiss Home Light → Swiss Home Dark → Color Light → Color Dark → System Light.
- Без сохранённого ручного выбора использовать System Light/System Dark по appearance macOS.
- После ручного выбора сохранённая конкретная тема имеет приоритет над appearance macOS.
- Не добавлять внешние зависимости, отдельное окно настроек или selector с названиями тем.

---

### Task 1: Модель и persistent-выбор темы

**Files:**
- Create: `Sources/QuickCalKit/QuickCalTheme.swift`
- Create: `Tests/QuickCalKitTests/QuickCalThemeTests.swift`

**Interfaces:**
- Produces: `QuickCalTheme: String, CaseIterable, Codable, Sendable`.
- Produces: `QuickCalTheme.next`, `QuickCalTheme.isDark`, `QuickCalTheme.systemDefault(isDark:)`.
- Produces: `@MainActor QuickCalThemeStore`, `resolvedTheme(systemIsDark:)`, `selectNext(systemIsDark:)`.
- Persists: `QuickCalTheme.rawValue` under `QuickCalThemeStore.defaultKey == "quickCalTheme.v1"`.

- [x] **Step 1: Write failing tests for the exact cycle**

```swift
@Test
func themesCycleThroughAllSixOptionsInApprovedOrder() {
    #expect(QuickCalTheme.allCases == [
        .systemLight, .systemDark,
        .swissLight, .swissDark,
        .colorLight, .colorDark,
    ])
    #expect(QuickCalTheme.systemLight.next == .systemDark)
    #expect(QuickCalTheme.systemDark.next == .swissLight)
    #expect(QuickCalTheme.swissLight.next == .swissDark)
    #expect(QuickCalTheme.swissDark.next == .colorLight)
    #expect(QuickCalTheme.colorLight.next == .colorDark)
    #expect(QuickCalTheme.colorDark.next == .systemLight)
}
```

- [x] **Step 2: Write failing tests for system default and persistence**

```swift
@Test
@MainActor
func missingManualSelectionFollowsSystemAppearance() {
    let fixture = defaultsFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let store = QuickCalThemeStore(userDefaults: fixture.defaults, key: "theme.test")

    #expect(store.resolvedTheme(systemIsDark: false) == .systemLight)
    #expect(store.resolvedTheme(systemIsDark: true) == .systemDark)
}

@Test
@MainActor
func manualSelectionPersistsAndOverridesLaterSystemChanges() {
    let fixture = defaultsFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let store = QuickCalThemeStore(userDefaults: fixture.defaults, key: "theme.test")

    #expect(store.selectNext(systemIsDark: false) == .systemDark)

    let restored = QuickCalThemeStore(userDefaults: fixture.defaults, key: "theme.test")
    #expect(restored.resolvedTheme(systemIsDark: false) == .systemDark)
    #expect(restored.resolvedTheme(systemIsDark: true) == .systemDark)
}
```

- [x] **Step 3: Run the focused tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter QuickCalThemeTests
```

Expected: compile failure because `QuickCalTheme` and `QuickCalThemeStore` do not exist.

- [x] **Step 4: Implement the minimal model and store**

```swift
public enum QuickCalTheme: String, CaseIterable, Codable, Sendable {
    case systemLight
    case systemDark
    case swissLight
    case swissDark
    case colorLight
    case colorDark

    public var next: QuickCalTheme {
        switch self {
        case .systemLight: .systemDark
        case .systemDark: .swissLight
        case .swissLight: .swissDark
        case .swissDark: .colorLight
        case .colorLight: .colorDark
        case .colorDark: .systemLight
        }
    }

    public var isDark: Bool {
        switch self {
        case .systemDark, .swissDark, .colorDark: true
        case .systemLight, .swissLight, .colorLight: false
        }
    }

    public static func systemDefault(isDark: Bool) -> QuickCalTheme {
        isDark ? .systemDark : .systemLight
    }
}
```

`QuickCalThemeStore` restores only a valid raw value, otherwise keeps
`manualTheme == nil`; `selectNext` resolves the current theme, advances once,
publishes the new value and writes its raw value to `UserDefaults`.

- [x] **Step 5: Run focused and full tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter QuickCalThemeTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/test.sh
```

Expected: focused suite and all existing suites pass.

- [x] **Step 6: Commit the tested theme model**

```bash
git add Sources/QuickCalKit/QuickCalTheme.swift \
  Tests/QuickCalKitTests/QuickCalThemeTests.swift
git commit -m "feat: add persistent QuickCal theme selection"
```

### Task 2: Localization and AppKit appearance

**Files:**
- Modify: `Sources/QuickCalKit/Localization.swift`
- Modify: `Sources/QuickCalKit/Resources/en.lproj/Localizable.strings`
- Modify: `Sources/QuickCalKit/Resources/ru.lproj/Localizable.strings`
- Modify: `Tests/QuickCalKitTests/LocalizationTests.swift`
- Modify: `Sources/QuickCal/QuickCalApp.swift`
- Modify: `Tests/QuickCalKitTests/PopoverAppearanceTests.swift`

**Interfaces:**
- Consumes: `QuickCalTheme.isDark`.
- Produces: `QuickCalLocalization.Key.nextTheme`.
- Produces: `PopoverAppearanceSynchronizer.apply(theme:to:)`.
- Injects: one shared `QuickCalThemeStore` into `CalendarPopoverView`.

- [x] **Step 1: Add failing localization assertions**

```swift
#expect(localization.string(.nextTheme) == "Следующая тема")
#expect(localization.string(.nextTheme) == "Next theme")
```

Add them to the existing Russian and English localization tests.

- [x] **Step 2: Add failing popover appearance tests**

```swift
PopoverAppearanceSynchronizer.apply(theme: .colorDark, to: popover)
#expect(popover.appearance?.name == .darkAqua)

PopoverAppearanceSynchronizer.apply(theme: .swissLight, to: popover)
#expect(popover.appearance?.name == .aqua)
```

- [x] **Step 3: Run focused tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter LocalizationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter PopoverAppearanceTests
```

Expected: compile failures for `.nextTheme` and `apply(theme:to:)`.

- [x] **Step 4: Add resources and appearance mapping**

Add:

```swift
case nextTheme = "settings.next_theme"
```

Resources:

```text
"settings.next_theme" = "Next theme";
"settings.next_theme" = "Следующая тема";
```

Map every `theme.isDark` to `.darkAqua`, otherwise `.aqua`, and keep the
existing `apply(_:to:)` helper.

- [x] **Step 5: Share the store with SwiftUI and synchronize live changes**

`QuickCalAppDelegate` owns:

```swift
private let themeStore = QuickCalThemeStore()
```

Create `CalendarPopoverView(themeStore:onThemeChanged:)`. Before showing the
popover resolve the theme from `application.effectiveAppearance`; when the
palette button changes the theme, invoke the callback and immediately apply the
new AppKit appearance.

- [x] **Step 6: Run focused tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter LocalizationTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter PopoverAppearanceTests
```

Expected: both focused suites pass.

- [x] **Step 7: Commit localization and appearance synchronization**

```bash
git add Sources/QuickCalKit/Localization.swift \
  Sources/QuickCalKit/Resources/en.lproj/Localizable.strings \
  Sources/QuickCalKit/Resources/ru.lproj/Localizable.strings \
  Tests/QuickCalKitTests/LocalizationTests.swift \
  Sources/QuickCal/QuickCalApp.swift \
  Tests/QuickCalKitTests/PopoverAppearanceTests.swift
git commit -m "feat: synchronize QuickCal theme appearance"
```

### Task 3: SwiftUI theme tokens and shared component styling

**Files:**
- Create: `Sources/QuickCal/QuickCalThemeStyle.swift`
- Modify: `Sources/QuickCal/CalendarPopoverView.swift`
- Modify: `Sources/QuickCal/CalendarGridView.swift`
- Modify: `Sources/QuickCal/CalendarDayCell.swift`
- Modify: `Sources/QuickCal/HoverControls.swift`

**Interfaces:**
- Consumes: `QuickCalTheme` and `QuickCalThemeStore`.
- Produces: `QuickCalThemeStyle(theme:)` with background, surface, text,
  weekend, today, selection, hover, border and corner-radius tokens.
- Produces: environment value `quickCalThemeStyle`.
- Preserves: existing `CalendarGridView` data and callbacks.

- [x] **Step 1: Define tokens for all concepts**

Implement `QuickCalThemeStyle` with exact tokens from the approved design:

```swift
let weekendColor: Color
let todayColor: Color
let selectionColor: Color
let primaryText: Color
let secondaryText: Color
let panelColor: Color
let panelBorderColor: Color
let hoverColor: Color
let outerCornerRadius: CGFloat
let panelCornerRadius: CGFloat
let controlCornerRadius: CGFloat
let usesUppercaseHeaders: Bool
let usesHeaderPill: Bool
```

Use dedicated `QuickCalThemeBackground` and `QuickCalCalendarSurface` views for
the System gradient/material, Swiss solid surface/top stripe and Color
light/Aurora backgrounds. Do not place theme conditionals in day-model code.

- [x] **Step 2: Restructure the popover without removing behavior**

Compose:

```text
full date
calendar surface
  navigation: previous | month | Сегодня | next
  weekday/day/week grid
utility footer: weeks | autostart | paintpalette | power
```

Use 360 pt with week numbers and 328 pt without. Keep `.task(id: month.start)`,
selected date callbacks, launch-at-login message, Reduce Motion and locale.

- [x] **Step 3: Apply tokens to grid and day states**

Pass or inject `QuickCalThemeStyle` so:

- weekday/week labels use `secondaryText`;
- non-working dates use `weekendColor`;
- Today uses `todayColor`;
- selection uses `selectionColor`;
- out-of-month dates retain reduced opacity;
- hover uses `hoverColor`;
- Swiss uses sharper segment radii;
- Color and System retain rounded segments.

- [x] **Step 4: Build the compact utility footer**

Keep both checkbox toggles functional. Add:

```swift
HoverIconButton(
    title: localization.string(.nextTheme),
    systemImage: "paintpalette",
    symbolSize: 15,
    controlSize: 30,
    action: selectNextTheme
)
```

Use `power` for quit. Both icon-only actions use help and accessibility labels.

- [x] **Step 5: Compile and run the full automated suite**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/test.sh
```

Expected: all tests pass with no Swift compiler warnings introduced by the
change.

- [x] **Step 6: Commit the six-theme SwiftUI**

```bash
git add Sources/QuickCal/QuickCalThemeStyle.swift \
  Sources/QuickCal/CalendarPopoverView.swift \
  Sources/QuickCal/CalendarGridView.swift \
  Sources/QuickCal/CalendarDayCell.swift \
  Sources/QuickCal/HoverControls.swift
git commit -m "feat: apply six QuickCal visual themes"
```

### Task 4: Production build and runtime visual verification

**Files:**
- Modify: `docs/verification-calendar-enhancements.md`
- Create: `docs/evidence/quickcal-six-themes-system-light.png`
- Create: `docs/evidence/quickcal-six-themes-system-dark.png`
- Create: `docs/evidence/quickcal-six-themes-swiss-light.png`
- Create: `docs/evidence/quickcal-six-themes-swiss-dark.png`
- Create: `docs/evidence/quickcal-six-themes-color-light.png`
- Create: `docs/evidence/quickcal-six-themes-color-dark.png`

**Interfaces:**
- Consumes: production `dist/QuickCal.app`.
- Produces: six runtime screenshots and recorded verification evidence.

- [x] **Step 1: Run the canonical test and production build**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/test.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/build-app.sh
```

- [x] **Step 2: Validate the bundle**

Run:

```bash
file dist/QuickCal.app/Contents/MacOS/QuickCal
lipo -archs dist/QuickCal.app/Contents/MacOS/QuickCal
codesign --verify --deep --strict --verbose=2 dist/QuickCal.app
```

Expected: arm64 executable and valid ad-hoc signature.

- [x] **Step 3: Launch the worktree build and verify all themes**

Launch `dist/QuickCal.app` without overwriting `/Applications/QuickCal.app`.
Open the popover, capture each theme after one palette click and verify:

- only one visible `Сегодня`;
- settings, theme and quit controls remain low emphasis;
- full six-theme order matches the model;
- current day, selected segment, weekend and out-of-month states stay legible;
- width changes when week numbers are toggled;
- theme persists after quit/relaunch.

- [x] **Step 4: Record evidence**

Add a dated section to `docs/verification-calendar-enhancements.md` containing
the exact commands, test count, bundle results, runtime observations and paths
to the six screenshots.

- [x] **Step 5: Re-run final verification after documentation**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/test.sh
git diff --check
git status --short
```

Expected: tests pass, `git diff --check` has no output, and status contains only
the planned source, test, documentation and evidence files.

- [x] **Step 6: Commit design and verification evidence**

```bash
git add docs/superpowers/specs/2026-07-30-quickcal-six-themes-design.md \
  docs/superpowers/plans/2026-07-30-quickcal-six-themes.md \
  docs/verification-calendar-enhancements.md \
  docs/evidence/quickcal-six-themes-*.png
git commit -m "docs: verify QuickCal six-theme design"
```
