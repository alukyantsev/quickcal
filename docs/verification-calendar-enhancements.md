# Проверка улучшений QuickCal — 2026-07-29

Ветка: `feature/quickcal-calendar-enhancements`.

Проверенный source state:

```text
b9927ee feat: use QuickCal clock badge menu icon
106c9fb feat: package QuickCal Finder icon
e674868 fix: make QuickCal icon fallback self-contained
e8f3ee8 feat: add QuickCal application icon assets
a1cd688 feat: enhance QuickCal calendar interactions
822eb50 fix: throttle stale calendar refresh failures
7514b01 feat: add Russian work calendar data
bce7f30 feat: follow system language in QuickCal
afa28fe feat: persist selected calendar dates
```

Установленный артефакт: `/Applications/QuickCal.app`.

## Автоматические проверки

Каноническая команда:

```bash
./Scripts/test.sh
```

Результат:

```text
ok - explicit SDKROOT performs one fresh arm64 release build
ok - localization resources are packaged with fail-fast validation
ok - QuickCal.icns is packaged with fail-fast validation
✔ Test run with 50 tests in 9 suites passed
Проверки пройдены: tests=50, errors=0, failures=0.
```

Покрыты:

- гражданские Gregorian-даты и отсутствие timezone drift;
- persistent JSON-store выбранных дат;
- сегменты `isolated/leading/middle/trailing`;
- ru/en локализация и английский fallback;
- даты без `г.` и `года`;
- ресурсный bundle внутри `.app`;
- строгий parser 365/366 кодов `0/1/2/8`;
- HTTPS endpoint, query, timeout и HTTP errors;
- memory/disk/stale cache;
- 24-часовой throttle неуспешного refresh;
- повторное принятие будущего года после появления данных;
- in-flight дедупликация;
- Saturday/Sunday fallback.

Сборка:

```bash
./Scripts/build-app.sh
```

Результат:

```text
Mach-O 64-bit executable arm64
valid on disk
satisfies its Designated Requirement
```

В bundle присутствуют:

```text
Contents/Resources/QuickCal_QuickCalKit.bundle/en.lproj/Localizable.strings
Contents/Resources/QuickCal_QuickCalKit.bundle/ru.lproj/Localizable.strings
Contents/Resources/QuickCal.icns
```

Контракт Finder icon проверен после release-сборки:

```bash
test -s dist/QuickCal.app/Contents/Resources/QuickCal.icns
test "$(/usr/bin/plutil -extract CFBundleIconFile raw \
    dist/QuickCal.app/Contents/Info.plist)" = "QuickCal.icns"
```

Обе команды завершились с exit `0`. `Support/QuickCal.icns`, ресурс в `dist` и
ресурс установленного bundle имеют одинаковый SHA-256:

```text
ef974764ffdf59b56dc6a220913f4b00c60492bb09d0ec4609bf7599401d44d6
```

Installed executable и `dist` имеют одинаковый SHA-256:

```text
4e9f159d4a7c4a1029805f14e42aee3e31af9db57f39232190d126c733e066f5
```

Проверка установленного bundle:

```text
/Applications/QuickCal.app/Contents/MacOS/QuickCal: Mach-O 64-bit executable arm64
/Applications/QuickCal.app: valid on disk
/Applications/QuickCal.app: satisfies its Designated Requirement
99214 /Applications/QuickCal.app/Contents/MacOS/QuickCal
```

Последняя строка — единственный запущенный process финального bundle.

## Finder icon acceptance

После `ditto` в `/Applications`, принудительной регистрации через `lsregister -f`
и запуска `/Applications/QuickCal.app` resolved icon получен через
`NSWorkspace.shared.icon(forFile:)`, а не скопирован из source asset.

`docs/evidence/quickcal-finder-icon.png` — PNG `2048×2048`, SHA-256:

```text
8ce483f5331d9bed52224c6de2589f271cda4d05432a2776fcf2a36b796a9c2a
```

Визуальная проверка resolved icon: синий squircle, белый календарь, clock badge
справа снизу; generic executable/grid icon отсутствует. Evidence содержит только
иконку с прозрачным фоном, без постороннего desktop content.

## Review

Task 4 проверяет артефакты Tasks 1–3 без изменения production Swift logic или
icon assets. `git diff --check` и итоговый clean-state check выполнены перед
commit.

## Runtime-приёмка

Проверка выполнена на установленном arm64 bundle через macOS Accessibility.
Основной Computer Use backend не увидел transient `MenuBarExtra` window и
вернул timeout, поэтому применён ранее разрешённый для QuickCal fallback:
System Events, native AX и `screencapture` только заданной области окна.

| Критерий | Фактический результат |
|---|---|
| Menu bar | `calendar.badge.clock`; свежий optical bbox `36×34 px`, высота `17.00 pt`, ratio к 17-pt reference — `1.000` |
| Finder icon | `QuickCal.icns` зарегистрирован в LaunchServices; resolved `NSWorkspace` evidence подтверждает синий squircle, белый календарь и clock badge |
| Popover с номерами недель | 342×460 для июля 2026 |
| Popover без номеров недель | 310×460; labels недель отсутствуют |
| Системный язык | `AppleLanguages = [en-US, ru-RU]`; обычный запуск показывает английский UI |
| Русский runtime | временный запуск с `-AppleLanguages (ru-RU)` показывает русский UI |
| Верхняя дата EN | `Wednesday, 29 July, 2026` |
| Верхняя дата RU | `среда, 29 июля 2026` |
| Месяц EN | `July 2026` |
| Месяц RU | `июль 2026` |
| Суффикс года | `г.`, `года` отсутствуют в обоих русских заголовках |
| Стрелки | две области 32×32, крупные chevron |
| Today | после перехода в август 2026 вернул июль 2026; после перехода в ноябрь 2025 также вернул июль 2026 |
| Weekend fallback | субботы и воскресенья отображаются красным |
| Будний праздник | 4 ноября 2026 имеет AX value `Выходной` |
| Рабочая суббота | 1 ноября 2025 не имеет `Выходной`; 2 ноября 2025 имеет `Выходной` |
| Live cache | получен валидный файл 2026 года длиной 365 байт |
| Выбор дат | 30 и 31 июля получили AX value `Selected` / `Выбрано` |
| Объединение | 30 и 31 июля визуально образовали один зелёный pill |
| Today priority | 29 июля остался синим с белым текстом рядом с зелёным pill |
| Persistence | после UI quit/relaunch обе даты сохранили `Selected` |
| Checkbox persistence | после final acceptance `defaults read local.andrei.quickcal showWeekNumbers` вернул `1` |
| Hover | визуально подтверждён animated hover-фон строки Quit; остальные hover-paths прошли source review и compile |
| Выход | UI-кнопка Quit завершила процесс |
| Финальный запуск | приложение запущено из `/Applications/QuickCal.app`, popover закрыт |

## Visual evidence

- [Menu bar icon через NSStatusItem](evidence/quickcal-menu-icon-nsstatusitem.png)
- [Clock badge menu icon](evidence/quickcal-menu-icon-clock.png)
- [Resolved Finder icon через NSWorkspace](evidence/quickcal-finder-icon.png)
- [Календарь 342 pt: red weekends, green pill, blue today](evidence/quickcal-calendar-enhancements.png)
- [Календарь 310 pt без недель и hover строки Quit](evidence/quickcal-calendar-enhancements-no-weeks-hover.png)

Снимки содержат только status item, окно QuickCal или resolved app icon, без
unrelated desktop content.

## Финальное состояние

- QuickCal запущен из `/Applications/QuickCal.app` (один process).
- Popover закрыт: `QuickCal on-screen windows: 0`.
- `showWeekNumbers` сохранён включённым: `1`.
- Системный английский UI активен; системные настройки языка не менялись.
- Состояние launch at login сохранено без изменения.
- Две тестовые отметки дат удалены после проверки.
- Валидный cache производственного календаря сохранён для offline-работы.
- Предыдущая установленная версия сохранена в
  `/Users/andrei.lukyantsev/Downloads/QuickCal-before-calendar-enhancements.app`.
