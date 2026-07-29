# План реализации улучшений QuickCal

Дата: 2026-07-29  
Ветка: `feature/quickcal-calendar-enhancements`

## Task 1. Гражданские даты и persistent-выбор

Файлы:

- создать `Sources/QuickCalKit/CalendarDate.swift`;
- создать `Sources/QuickCalKit/SelectedDatesStore.swift`;
- создать `Sources/QuickCalKit/SelectionSegment.swift`;
- создать `Tests/QuickCalKitTests/SelectedDatesStoreTests.swift`;
- создать `Tests/QuickCalKitTests/SelectionSegmentTests.swift`.

Шаги:

1. Написать падающие тесты для Gregorian-компонентов, toggle, восстановления JSON, повреждённых данных и timezone independence.
2. Написать тесты формы соседних выбранных дней внутри недели.
3. Реализовать минимальные модели и injected `UserDefaults`.
4. Запустить `./Scripts/test.sh`.
5. Commit: `feat: persist selected calendar dates`.

## Task 2. Локализация и формат дат

Файлы:

- изменить `Package.swift`;
- создать `Sources/QuickCalKit/Localization.swift`;
- создать `Sources/QuickCalKit/DatePresentation.swift`;
- создать `Sources/QuickCalKit/Resources/en.lproj/Localizable.strings`;
- создать `Sources/QuickCalKit/Resources/ru.lproj/Localizable.strings`;
- изменить `Sources/QuickCalKit/LaunchAtLoginController.swift`;
- изменить `Tests/QuickCalKitTests/LaunchAtLoginControllerTests.swift`;
- создать `Tests/QuickCalKitTests/LocalizationTests.swift`;
- создать `Tests/QuickCalKitTests/DatePresentationTests.swift`;
- изменить `Support/Info.plist`;
- изменить `Scripts/build-app.sh`;
- изменить `Tests/BuildScriptTests/build-app-tests.sh`.

Шаги:

1. Написать падающие тесты ru/en/fallback и форматов без `г.`/`года`.
2. Добавить SwiftPM resource bundle с `defaultLocalization: "en"`.
3. Реализовать единый resolver и локализованные строки.
4. Перевести LaunchAtLoginController на локализацию с injectable locale.
5. Добавить копирование `QuickCal_QuickCalKit.bundle` в `.app` и fail-fast при его отсутствии.
6. Расширить build-script regression test.
7. Запустить `./Scripts/test.sh` и `./Scripts/build-app.sh`.
8. Commit: `feat: follow system language in QuickCal`.

## Task 3. Производственный календарь

Файлы:

- создать `Sources/QuickCalKit/RussianWorkCalendar.swift`;
- создать `Sources/QuickCalKit/IsDayOffClient.swift`;
- создать `Sources/QuickCalKit/RussianWorkCalendarCache.swift`;
- создать `Sources/QuickCalKit/RussianWorkCalendarRepository.swift`;
- создать `Tests/QuickCalKitTests/RussianWorkCalendarParserTests.swift`;
- создать `Tests/QuickCalKitTests/IsDayOffClientTests.swift`;
- создать `Tests/QuickCalKitTests/RussianWorkCalendarRepositoryTests.swift`.

Шаги:

1. Написать падающие тесты строгого parser для 365/366 дней, leap day и кодов `0/1/2/8`.
2. Написать тесты endpoint/query, timeout, HTTPS и HTTP errors.
3. Написать тесты memory/disk cache, stale fallback, атомарное сохранение и дедупликацию запросов.
4. Реализовать Sendable-модели и injected HTTP loader.
5. Реализовать actor repository и Saturday/Sunday fallback.
6. Запустить `./Scripts/test.sh`.
7. Commit: `feat: add Russian work calendar data`.

## Task 4. Controller и SwiftUI-интеграция

Файлы:

- изменить `Sources/QuickCal/QuickCalApp.swift`;
- изменить `Sources/QuickCal/CalendarPopoverView.swift`;
- изменить `Sources/QuickCal/CalendarGridView.swift`;
- создать `Sources/QuickCal/CalendarDayCell.swift`;
- создать `Sources/QuickCal/HoverControls.swift`;
- создать `Sources/QuickCal/WorkCalendarController.swift`.

Шаги:

1. Добавить custom label menu bar icon 18 pt / 22×22.
2. Добавить controller загрузки всех Gregorian years текущей сетки.
3. Перевести UI на локализованные строки и локализованный Calendar.
4. Добавить Today-кнопку и увеличенные стрелки.
5. Реализовать динамическую ширину 342/310.
6. Реализовать hover-кнопки, hover-строки настроек, quit и day cells.
7. Подключить persistent selection и непрерывные зелёные сегменты.
8. Подключить authoritative workday status и красный текст.
9. Сохранить blue-over-green приоритет текущего дня.
10. Запустить `./Scripts/test.sh` и `swift build`.
11. Commit: `feat: enhance QuickCal calendar interactions`.

## Task 5. Интеграционная проверка

Шаги:

1. Запустить `./Scripts/test.sh`.
2. Запустить `./Scripts/build-app.sh`.
3. Проверить:

   ```bash
   file dist/QuickCal.app/Contents/MacOS/QuickCal
   lipo -archs dist/QuickCal.app/Contents/MacOS/QuickCal
   codesign --verify --deep --strict --verbose=2 dist/QuickCal.app
   plutil -p dist/QuickCal.app/Contents/Info.plist
   find dist/QuickCal.app/Contents/Resources -maxdepth 4 -type f -print
   ```

4. Установить новую сборку в `/Applications/QuickCal.app`.
5. Проверить русский runtime, затем английский runtime с перезапуском приложения.
6. Проверить hover, Today, ширину, weekend/holiday/workday overrides и persistent selection.
7. Сохранить screenshot/evidence и обновить `docs/verification.md`.
8. Выполнить отдельное code review субагентом.
9. Исправить найденные проблемы и повторить полный verification.
10. Commit: `test: verify QuickCal calendar enhancements`.

## Task 6. Завершение ветки

1. Убедиться, что `git status --short` пуст.
2. Показать пользователю ветку `feature/quickcal-calendar-enhancements` и итоговые commit-ы.
3. Не объединять новую ветку в `main` без отдельной команды пользователя.
