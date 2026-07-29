# Проверка QuickCal — 2026-07-29

Проверенный commit приложения: `6896126 fix: treat missing login item as disabled`.

Установленный артефакт: `/Applications/QuickCal.app`.

## Окружение

В отчёт включены только безопасные host facts:

```text
Model Name: MacBook Air
Model Identifier: Mac16,13
Chip: Apple M4
macOS: 26.5.2
Architecture: arm64
```

Serial number, hardware UUID, provisioning UDID, username и другие
операционные идентификаторы в отчёт не включены.

## Автоматические проверки

### Почему plain `swift test` недостаточно

Фактически выполнена команда:

```bash
swift test
```

Результат: exit code `0`, сборка завершается строкой:

```text
Build complete! (1.81s)
```

При этом в выводе нет `Test run started`, списка тестов или итогового test
result. В этом Command Line Tools окружении target-local framework path не
попадает в автоматически сгенерированный SwiftPM runner. Поэтому plain-команда
собирает package и runner, но не подтверждает фактическое исполнение Apple
Swift Testing suite.

### Поддерживаемый полный Swift Testing suite

Команда:

```bash
swift test --disable-xctest --enable-swift-testing \
  -Xswiftc -F \
  -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  --xunit-output /private/tmp/quickcal-review-xunit.xml
```

Результат:

```text
✔ Test run with 11 tests in 2 suites passed after 0.002 seconds.
```

xUnit:

```xml
<testsuite name="TestResults" errors="0" tests="11" failures="0" skipped="0" time="0.00219475">
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

### Проверка diff

Команда:

```bash
git diff --check
```

Результат: exit code `0`, stdout пуст.

## Установка и bundle

До первой установки на Task 5 путь был свободен:

```bash
test ! -e /Applications/QuickCal.app
```

Результат: exit code `0`. Поэтому `/Applications/QuickCal.app` не был чужим
bundle: он впервые создан нами из проверенного `dist/QuickCal.app` командой:

```bash
ditto dist/QuickCal.app /Applications/QuickCal.app
```

После TDD-fix обновлялся только этот же in-scope bundle. До обновления были
повторно проверены оба bundle id и SHA старого установленного executable:

```text
source_id=local.andrei.quickcal
target_id=local.andrei.quickcal
old installed SHA-256:
c1727317571ec707b2d8eff659e50ec7485e39f07c28b2dd1e1c0ad9b2f603cb
```

Отдельное согласование происхождения существующего bundle не требовалось и не
заявляется: его происхождение уже было установлено фактом свободного пути до
первой установки и нашей собственной установкой на предыдущем шаге Task 5.

Перед обновлением текущий QuickCal завершён штатной кнопкой
«Выйти из QuickCal». `pgrep -x QuickCal` завершился с кодом `1`.

Обновление:

```bash
ditto dist/QuickCal.app /Applications/QuickCal.app
```

Точные команды сравнения после обновления:

```bash
shasum -a 256 \
  /Applications/QuickCal.app/Contents/MacOS/QuickCal \
  dist/QuickCal.app/Contents/MacOS/QuickCal

cmp \
  /Applications/QuickCal.app/Contents/MacOS/QuickCal \
  dist/QuickCal.app/Contents/MacOS/QuickCal
```

Оба пути и результаты:

```text
5ccea7363089fb25f05b7bce1a9da665040bed87878ccb5519a06efe26f3bb5e  /Applications/QuickCal.app/Contents/MacOS/QuickCal
5ccea7363089fb25f05b7bce1a9da665040bed87878ccb5519a06efe26f3bb5e  dist/QuickCal.app/Contents/MacOS/QuickCal

cmp: exit code 0
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

- [Popover](evidence/quickcal-popover.png)

Это единственное durable visual evidence: изображение фиксирует безопасное
финальное состояние самого QuickCal. Screenshots menu bar и Dock намеренно не
включены в репозиторий, потому что вместе с проверяемыми элементами они
захватывают unrelated desktop context.

Menu bar и отсутствие QuickCal в Dock подтверждены AX и runtime observations.
Переходы месяцев, OFF/ON, persistence, close/reopen и quit также подтверждены
приведёнными выше AX observations и process checks.

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
