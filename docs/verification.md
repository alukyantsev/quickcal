# Проверка QuickCal — 2026-07-29

Проверенный commit приложения: `6896126 fix: treat missing login item as disabled`.

Установленный артефакт: `/Applications/QuickCal.app`.

## Автоматические проверки

### Swift Testing

Команда:

```bash
swift test --disable-xctest --enable-swift-testing \
  -Xswiftc -F \
  -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  --xunit-output /private/tmp/quickcal-task5-fix-xunit/results.xml
```

Результат:

```text
✔ Test run with 11 tests in 2 suites passed after 0.001 seconds.
```

xUnit:

```xml
<testsuite name="TestResults" errors="0" tests="11" failures="0" skipped="0">
```

### Release-сборка

Команда:

```bash
./Scripts/build-app.sh
```

Результат: exit code `0`.

```text
Build complete! (1.73s)
dist/QuickCal.app/Contents/MacOS/QuickCal: Mach-O 64-bit executable arm64
dist/QuickCal.app: valid on disk
dist/QuickCal.app: satisfies its Designated Requirement
Готово: .../dist/QuickCal.app
```

## Установка и bundle

Перед обновлением текущий QuickCal завершён штатной кнопкой
«Выйти из QuickCal». `pgrep -x QuickCal` завершился с кодом `1`.

Bundle id исходного и установленного приложений проверен до обновления:

```text
source_id=local.andrei.quickcal
target_id=local.andrei.quickcal
```

Обновление:

```bash
ditto dist/QuickCal.app /Applications/QuickCal.app
```

После обновления:

```text
SHA-256:
5ccea7363089fb25f05b7bce1a9da665040bed87878ccb5519a06efe26f3bb5e

cmp installed/dist: exit code 0
codesign --verify --deep --strict: valid on disk
lipo -archs: arm64
CFBundleIdentifier: local.andrei.quickcal
LSMinimumSystemVersion: 14.0
LSUIElement: true
```

## Runtime-приёмка

Проверка выполнена на macOS через разрешённые пользователем System Events,
`osascript` и `screencapture`.

| Критерий | Фактический результат |
|---|---|
| Запуск установленного приложения | `open /Applications/QuickCal.app`; процесс запустился |
| Dock | QuickCal отсутствует |
| Menu bar | Монохромная system calendar icon присутствует; AX title `Календарь`, role `AXMenuBarItem` |
| Popover | Открывается в system appearance: `AXWindow`, `AXSystemDialog`, размер `342×417`; повторный AXPress закрывает его, `window count=0` |
| Ошибка `.notFound` | Ложного текста «Установите QuickCal…» нет |
| Текущая дата | `среда, 29 июля 2026 г.` |
| Текущий месяц | `июль 2026 г.` |
| Сетка | Пн–Вс, пять полных недель, номера 27–31 |
| Сегодня | Ячейка `29` имеет AX value `Сегодня`; визуально выделена текущим синим macOS accent color |
| Назад/вперёд | `июль 2026` → `июнь 2026` → `июль 2026` |
| Граница года | `декабрь 2026` → `январь 2027` → `декабрь 2026` |
| Номера недель OFF | Checkbox `0`, AX-элементов `49`, week-number labels отсутствуют |
| Persistence OFF | После quit/relaunch checkbox остался `0` |
| Номера недель ON | Checkbox `1`, AX-элементов `54`, видны `Неделя 27` — `Неделя 31` |
| Persistence ON | После quit/relaunch checkbox остался `1` |
| Launch at login ON | OFF → ON: checkbox стал `1`, ошибок и `requiresApproval` нет |
| Launch at login после reopen | После закрытия/повторного открытия popover checkbox остался `1` |
| Launch at login OFF | ON → OFF: checkbox стал `0`, ошибок нет |
| Финальное состояние login item | После закрытия/повторного открытия popover checkbox остался `0` |
| Выход | Кнопка «Выйти из QuickCal» завершила процесс; `pgrep -x QuickCal` вернул код `1` |

## Visual evidence

- Menu bar:
  `/private/tmp/quickcal-runtime-6896126-menubar.png`
- Dock:
  `/private/tmp/quickcal-runtime-6896126-dock.png`
- Popover:
  `/private/tmp/quickcal-runtime-6896126-popover.png`

Popover screenshot показывает:

- system dark appearance;
- полную дату и текущий месяц;
- grid Пн–Вс;
- выделение 29-го системным accent color;
- включённые номера недель;
- выключенный launch-at-login;
- отсутствие ложного `.notFound` сообщения.

Системный `AppleAccentColor` не переопределён: `defaults read -g
AppleAccentColor` сообщает, что пара domain/default отсутствует. Цвет
подсветки в приложении соответствует текущему системному default accent;
системную настройку во время проверки не меняли.

## Ограничение метода

Первичный backend Computer Use не возвращал AX state и завершался timeout.
После явного разрешения пользователя применён встроенный macOS fallback.

Menu bar item и transient popover находились на display с отрицательным
глобальным Y origin. Обычный fullscreen `screencapture` не сохранял popover.
Его onscreen CoreGraphics window id был получен read-only и передан в
`screencapture -l`; приложение и системные настройки для этого не изменялись.

## Финальное состояние

- QuickCal снова запущен, PID на момент проверки: `38129`.
- Popover закрыт.
- Номера недель включены.
- Launch at login выключен.
- Системный accent color не изменён.
