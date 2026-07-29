# Проверка улучшений QuickCal — 2026-07-29

Ветка: `feature/quickcal-calendar-enhancements`.

Проверенный source state:

```text
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
```

Installed executable и `dist` имеют одинаковый SHA-256:

```text
b2ca7270cc1fa54514a3da00fccb3f9bf95a76f79d1f991686183820d0bc26aa
```

`lsof` подтвердил, что финальный процесс загрузил:

```text
/Applications/QuickCal.app/Contents/MacOS/QuickCal
```

## Review

Реализация выполнена через субагентов.

- Spec-review Tasks 1–3: PASS.
- Code-quality review Tasks 1–3 нашёл один P2: повторный запрос при stale
  cache и offline-сети. Исправлено в `822eb50`, добавлен regression test.
- Spec-review Task 4: PASS.
- Code-quality review Task 4: PASS.

## Runtime-приёмка

Проверка выполнена на установленном arm64 bundle через macOS Accessibility.
Основной Computer Use backend не увидел transient `MenuBarExtra` window и
вернул timeout, поэтому применён ранее разрешённый для QuickCal fallback:
System Events, native AX и `screencapture` только заданной области окна.

| Критерий | Фактический результат |
|---|---|
| Menu bar | `AXMenuBarItem`, `AXMenuExtra`, размер 34×24; custom calendar glyph визуально крупнее базовой версии |
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
| Checkbox persistence | `showWeekNumbers=0` сохранился после quit/relaunch |
| Hover | визуально подтверждён animated hover-фон строки Quit; остальные hover-paths прошли source review и compile |
| Выход | UI-кнопка Quit завершила процесс |
| Финальный запуск | приложение запущено из `/Applications/QuickCal.app`, popover закрыт |

## Visual evidence

- [Увеличенная menu bar icon](evidence/quickcal-menu-icon.png)
- [Календарь 342 pt: red weekends, green pill, blue today](evidence/quickcal-calendar-enhancements.png)
- [Календарь 310 pt без недель и hover строки Quit](evidence/quickcal-calendar-enhancements-no-weeks-hover.png)

Снимки содержат только status item или окно QuickCal, без unrelated desktop
content.

## Финальное состояние

- QuickCal запущен из `/Applications/QuickCal.app`.
- Popover закрыт.
- Системный английский UI активен; системные настройки языка не менялись.
- Номера недель включены.
- Состояние launch at login сохранено без изменения.
- Две тестовые отметки дат удалены после проверки.
- Валидный cache производственного календаря сохранён для offline-работы.
- Предыдущая установленная версия сохранена в
  `/Users/andrei.lukyantsev/Downloads/QuickCal-before-calendar-enhancements.app`.
