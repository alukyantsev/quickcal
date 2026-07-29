# Проверка QuickCal — 2026-07-29

Проверенный commit приложения: `377be73 fix: expose month navigation labels`.

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

### Каноническая команда

Команда:

```bash
./Scripts/test.sh
```

Результат:

```text
ok - explicit SDKROOT performs one fresh arm64 release build
✔ Test run with 11 tests in 2 suites passed after 0.002 seconds.
Проверки пройдены: tests=11, errors=0, failures=0.
```

Скрипт сначала запускает shell regression suite
`Tests/BuildScriptTests/build-app-tests.sh`, затем Apple Swift Testing с
обнаруженным `Testing.framework` и обязательным непустым xUnit. Он завершился
с кодом `0`: 11 тестов в 2 suites, 0 errors, 0 failures.

### Почему plain `swift test` не является канонической проверкой

На этом же host ранее отдельно выполнялся `swift test`: команда завершалась с
кодом `0` после сборки, но без `Test run started`, списка тестов и итогового
test result. Поэтому такой вывод не использован как доказательство исполнения
suite. Финальная проверка commit `377be73` выполнена только через
`./Scripts/test.sh`, который явно настраивает framework path и проверяет xUnit.

### Release-сборка

Каноническая команда:

```bash
./Scripts/build-app.sh
```

Финальный handoff build выполнен координатором на том же app source commit
`377be73`. Результат: exit code `0`.

```text
Build complete! (1.86s)
dist/QuickCal.app/Contents/MacOS/QuickCal: Mach-O 64-bit executable arm64
dist/QuickCal.app: valid on disk
dist/QuickCal.app: satisfies its Designated Requirement
Готово: .../dist/QuickCal.app
```

Дополнительно на реальном SDK path повторена ветка явного `SDKROOT`:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  ./Scripts/build-app.sh
```

Результат: exit code `0`.

```text
Build complete! (4.14s)
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

После этого обновлялся только тот же in-scope bundle. Перед финальным
handoff-обновлением coordinator build из того же app source commit `377be73`
были повторно проверены оба bundle id и SHA старого установленного executable:

```text
source_id=local.andrei.quickcal
target_id=local.andrei.quickcal
old installed SHA-256:
33c7b06ef20bb5c52c44c8d5466f43a5c4ba4ecccd3e4141a8f516fc6e21ab1f
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
65b2e135e9a703d8577b4efab6ddf1c60a689892076e2cb2eced5d6123f4ff6c  /Applications/QuickCal.app/Contents/MacOS/QuickCal
65b2e135e9a703d8577b4efab6ddf1c60a689892076e2cb2eced5d6123f4ff6c  dist/QuickCal.app/Contents/MacOS/QuickCal

cmp: exit code 0
codesign --verify --deep --strict: valid on disk
lipo -archs: arm64
CFBundleIdentifier: local.andrei.quickcal
LSMinimumSystemVersion: 14.0
LSUIElement: true
```

После запуска `lsof -a -p <pid> -d txt -Fn` подтвердил загруженный executable
`/Applications/QuickCal.app/Contents/MacOS/QuickCal`; его SHA совпал с
установленным и `dist` hash выше.

## Runtime-приёмка

Проверка выполнена на macOS через разрешённые пользователем System Events,
`osascript`, native Accessibility API и `screencapture`.

Полная runtime-приёмка ниже выполнена для app source commit `377be73`. После
финальной coordinator rebuild исходный код приложения не менялся. Exact
handoff binary с новым SHA установлен повторно, и для него отдельно повторён
минимальный runtime smoke.

| Критерий | Фактический результат |
|---|---|
| Запуск установленного приложения | `open /Applications/QuickCal.app`; загружен exact handoff executable с SHA-256 `65b2e135…f4ff6c` |
| Dock | QuickCal отсутствует |
| Menu bar | Монохромная system calendar icon присутствует; AX title `Календарь`, role `AXMenuBarItem` |
| Popover | Открывается в system appearance: `AXWindow`, `AXSystemDialog`, размер `342×417`; повторный AXPress закрывает его, `window count=0` |
| Ошибка `.notFound` | Ложного текста «Установите QuickCal…» нет |
| Текущая дата | `среда, 29 июля 2026 г.` |
| Текущий месяц | `июль 2026 г.` |
| Сетка | Пн–Вс, пять полных недель, номера 27–31 |
| Locale-aware digits | Day и week numbers реализованы через `Text(..., format: .number)`, week AX label — через локализованный `Text` interpolation; в текущей русской locale отображаются `1`–`31` и `Неделя 27`–`Неделя 31` |
| Сегодня | AX содержит semantic value `Сегодня`; ячейка `29` визуально выделена текущим синим macOS accent color |
| AX label назад | Левый `AXButton`, global X `2893`, `AXIdentifier=chevron.left`; native `AXDescription` и `AXAttributedDescription` равны `Предыдущий месяц` |
| AX label вперёд | Правый `AXButton`, global X `3194.5`, `AXIdentifier=chevron.right`; native `AXDescription` и `AXAttributedDescription` равны `Следующий месяц` |
| Назад/вперёд | `июль 2026` → `июнь 2026` → `июль 2026` |
| Граница года | `июль 2026` → `декабрь 2026` → `январь 2027` → `декабрь 2026` → `июль 2026`; все значения прочитаны как AX month titles |
| Номера недель OFF | Checkbox `0`, AX-элементов `49`, week-number labels отсутствуют |
| Persistence OFF | После штатного UI quit (`pgrep` exit `1`) и relaunch checkbox остался `0`, AX-элементов `49`, week-number labels отсутствуют |
| Номера недель ON | Checkbox `1`, AX-элементов `54`, видны `Неделя 27` — `Неделя 31` |
| Persistence ON | После штатного UI quit (`pgrep` exit `1`) и relaunch checkbox остался `1`, AX-элементов `54`, видны `Неделя 27` — `Неделя 31` |
| Launch at login ON | OFF → ON: checkbox стал `1`; список AX texts не содержит сообщения об ошибке или `requiresApproval` |
| Launch at login после reopen | После закрытия/повторного открытия popover checkbox остался `1`, сообщений нет |
| Launch at login OFF | ON → OFF: checkbox стал `0`, сообщений нет |
| Финальное состояние login item | После закрытия/повторного открытия popover и после quit/relaunch checkbox остался `0` |
| Выход | Кнопка «Выйти из QuickCal» завершила процесс; `pgrep -x QuickCal` вернул код `1` |
| Финальный relaunch | Новый процесс запущен из `/Applications/QuickCal.app`; persisted state: week numbers `1`, launch at login `0`; popover снова закрыт |
| Handoff smoke | `lsof` показывает installed executable с SHA `65b2e135…f4ff6c`; QuickCal отсутствует в Dock; status item `Календарь` имеет role `AXMenuBarItem`; popover `342×417` открывается; обе semantic navigation labels доступны; week numbers `1`, login `0`, сообщений нет; popover закрыт |

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

Screenshot не перезаписывался при handoff: coordinator build собран из того же
app source commit `377be73`, визуальное содержимое не изменилось, а совпадение
финального UI state подтверждено повторным smoke exact binary.

Системный `AppleAccentColor` не переопределён: `defaults read -g
AppleAccentColor` сообщает, что пара domain/default отсутствует. Цвет
подсветки в приложении соответствует текущему системному default accent;
системную настройку во время проверки не меняли.

## Ограничение метода

Первичный backend Computer Use не возвращал AX state и завершался timeout.
После явного разрешения пользователя применён встроенный macOS fallback.

Menu bar item и transient popover находились на display с отрицательным
глобальным Y origin. Onscreen CoreGraphics window id был получен read-only и
передан в `screencapture -l`. Поэтому файл содержит только окно QuickCal, без
menu bar, Dock и другого desktop context.

System Events показывает semantic SwiftUI label как нечитаемый
`AXAttributedDescription`. Для точной проверки его значение было прочитано
read-only через native Accessibility API: обе navigation labels совпали с
русскими строками выше.

## Финальное состояние

- QuickCal снова запущен, PID на момент проверки: `57876`.
- Загружен `/Applications/QuickCal.app/Contents/MacOS/QuickCal` с SHA-256
  `65b2e135e9a703d8577b4efab6ddf1c60a689892076e2cb2eced5d6123f4ff6c`.
- Popover закрыт.
- Номера недель включены.
- Launch at login выключен.
- Системный accent color не изменён.
