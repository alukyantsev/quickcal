# Проверка улучшений QuickCal — 2026-07-29

Ветка: `feature/quickcal-calendar-enhancements`.

Проверенный source state:

```text
e3398a3 fix: refresh production calendar data reliably
29f3a90 fix: reserve space for calendar header controls
783f712 feat: package modern QuickCal app icon
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
ok - Assets.car is packaged without copying the raw Icon Composer source
ok - modern icon generator publishes the AppIcon Assets.car produced by actool
ok - modern icon generator fails clearly when actool is unavailable
✔ Test run with 54 tests in 11 suites passed
Проверки пройдены: tests=54, errors=0, failures=0.
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
- 24-часовой throttle неуспешного refresh с кешем и без кеша;
- повторное обновление текущего и будущего года в долгоживущем приложении;
- fresh disk cache не сдвигает время следующего сетевого refresh;
- завершённые прошлые годы не запрашиваются повторно;
- in-flight дедупликация;
- Saturday/Sunday fallback;
- compact header layout для длинных EN/RU названий месяца.

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
Contents/Resources/Assets.car
Contents/Resources/QuickCal.icns
```

Контракт modern Finder icon проверен после release-сборки:

```bash
test -s dist/QuickCal.app/Contents/Resources/Assets.car
test "$(/usr/bin/plutil -extract CFBundleIconName raw \
    dist/QuickCal.app/Contents/Info.plist)" = "AppIcon"
```

Обе команды завершились с exit `0`. `assetutil --info` подтверждает записи
`AppIcon` в установленном `Assets.car`. `Support/Assets.car`, ресурс в `dist` и
ресурс установленного bundle имеют одинаковый SHA-256:

```text
a3a0dc412a49b6b670e579f0f68cfd319b187db60108b2393bf0ca5c349af1b9
```

Installed executable и `dist` имеют одинаковый SHA-256:

```text
7361e68b5277834fda37d0677957b4328378d548fa27bae2b25e3308d70d1c3c
```

Проверка установленного bundle:

```text
/Applications/QuickCal.app/Contents/MacOS/QuickCal: Mach-O 64-bit executable arm64
/Applications/QuickCal.app: valid on disk
/Applications/QuickCal.app: satisfies its Designated Requirement
37681 /Applications/QuickCal.app/Contents/MacOS/QuickCal
```

Последняя строка — единственный запущенный process финального bundle.

## Finder icon acceptance

После `ditto` в `/Applications`, принудительной регистрации через `lsregister -f`
и запуска `/Applications/QuickCal.app` resolved icon получен через
`NSWorkspace.shared.icon(forFile:)`, а не скопирован из source asset.

`docs/evidence/quickcal-finder-icon.png` — PNG `1024×1024` с alpha, SHA-256:

```text
523763a1b20ec819ae57876763ea8a271ab97ac68862723ef6cd47a2b9f166b6
```

Визуальная проверка resolved icon: синий modern app icon, белый календарь,
clock badge справа снизу. Большая серая generic Tahoe-плитка из предыдущей
проверки отсутствует; дополнительной системной squircle-оболочки вокруг
готового artwork нет. Evidence содержит только иконку с прозрачным фоном, без
постороннего desktop content.

## Review

Task 4 проверяет артефакты Tasks 1–3 без изменения production Swift logic или
icon assets. Предыдущая legacy-acceptance признана недействительной в fix
round 2; текущая приёмка выполнена заново после integration modern
`Assets.car` в commit `783f712`.

## Runtime-приёмка

Проверка выполнена на установленном arm64 bundle через macOS Accessibility.
Основной Computer Use backend не увидел transient `MenuBarExtra` window и
вернул timeout, поэтому применён ранее разрешённый для QuickCal fallback:
System Events, native AX и `screencapture` только заданной области окна.

| Критерий | Фактический результат |
|---|---|
| Menu bar | `calendar.badge.clock`; ранее подтверждённый optical bbox `36×34 px`, высота `17.00 pt`, ratio к 17-pt reference — `1.000`. В текущем multi-display layout свежий `screencapture -R3187,-247,40,24` не создал image из-за отрицательной Y-координаты; production bundle при этом не менялся |
| Finder icon | `CFBundleIconName=AppIcon`, compiled `Assets.car` зарегистрирован в LaunchServices; resolved `NSWorkspace` evidence подтверждает modern QuickCal artwork без серой generic Tahoe-плитки |
| Popover с номерами недель | 342×460 для июля 2026 |
| Popover без номеров недель | 310×460; labels недель отсутствуют |
| Длинный заголовок месяца | в compact width симметрично зарезервировано по 64 pt под controls; `September 2026` и `сентябрь 2026` не пересекаются с Today/Next |
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
