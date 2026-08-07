# Weather forecast in QuickCal

**Status:** done

## Problem Statement

Пользователь QuickCal видит производственный календарь и сроки, но не может в том же коротком взаимодействии оценить ближайшую погоду для выбранного места. Ему нужен компактный почасовой прогноз, не нарушающий приоритет календарной сетки и работающий во всех 16 темах.

## Solution

Добавить под календарной сеткой постоянно раскрытую погодную ленту. Она показывает ровно четыре периода с выбранным интервалом 2/4/8/12 часов и прокручивается к дальнейшему прогнозу; начальный горизонт поэтому равен четырём таким периодам. Каждый период показывает температуру, влажность, вероятность осадков и погодный символ.

Прогноз получает Open-Meteo без ключа: геокодер выбирает конкретный город с координатами, forecast API возвращает почасовые UTC timestamps, температуру, относительную влажность, вероятность осадков и weather code. QuickCal сохраняет timestamps как абсолютные instants, выбирает периоды хронологически и форматирует их в локальном часовом поясе Mac. Таким образом, данные относятся к месту прогноза, но подписи времени соответствуют текущему часовому поясу пользователя.

QuickCal обновляет прогноз и automatic location каждые 30 минут, пока приложение запущено в строке меню, независимо от состояния popover. Открытие popover читает текущий кеш без ожидания сети. Ручное обновление доступно для stale и error состояний.

## User Stories

1. Как пользователь QuickCal, я хочу видеть погодную ленту сразу под календарём, чтобы сопоставить даты и ближайшие условия без отдельного приложения.
2. Как пользователь, я хочу видеть ровно четыре периода в начальном viewport, чтобы прогноз оставался компактным.
3. Как пользователь, я хочу видеть температуру для каждого периода, чтобы быстро оценить погоду.
4. Как пользователь, я хочу видеть влажность и вероятность осадков с разными символами, чтобы не путать два процента.
5. Как пользователь, я хочу прокручивать прогноз вправо, чтобы видеть более дальние часы.
6. Как пользователь, я хочу видеть стрелку назад только после прокрутки вправо, чтобы вернуться к ближайшему прогнозу.
7. Как пользователь, я хочу менять интервал на 2, 4, 8 или 12 часов, чтобы управлять плотностью данных.
8. Как пользователь, я хочу, чтобы смена интервала действительно меняла временные точки, а не только ширину карточек.
9. Как пользователь, я хочу отключить погодный блок в настройках, если он мне не нужен.
10. Как пользователь, я хочу выбрать город через поиск и подсказки «город, регион, страна», чтобы не получать прогноз для одноимённого места.
11. Как пользователь, я хочу, чтобы выбранное место сохранялось как название и координаты, чтобы не искать его повторно.
12. Как пользователь, я хочу включить automatic location отдельным переключателем, чтобы системный запрос разрешения не появлялся без моего действия.
13. Как пользователь, я хочу, чтобы automatic location переопределялась каждые 30 минут, пока QuickCal работает, чтобы прогноз следовал за перемещением.
14. Как пользователь, я хочу при отказе в геолокации продолжать видеть последнее автоматическое или ручное место, чтобы функция не исчезала без причины.
15. Как новый пользователь, я не хочу видеть пустой или выдуманный прогноз, если места ещё нет.
16. Как пользователь, я хочу, чтобы при отсутствии места погодный блок не отображался, даже если опция погоды включена.
17. Как пользователь, я хочу видеть отметку «Обновлено …» для кеша старше 30 минут, чтобы понимать свежесть данных.
18. Как пользователь, я хочу видеть stale кеш не старше 24 часов, чтобы прогноз не пропадал при временной проблеме сети.
19. Как пользователь, я хочу видеть «Прогноз временно недоступен» и «Обновить прогноз», если кеш старше 24 часов или данные не загрузились.
20. Как пользователь, я хочу вручную обновить прогноз, чтобы не ждать следующего 30-минутного цикла.
21. Как пользователь, я хочу, чтобы время прогноза отображалось в моём локальном часовом поясе Mac, даже если место находится в другом поясе.
22. Как пользователь, я хочу, чтобы визуальные токены погоды соответствовали выбранной теме, чтобы новая функция не выглядела отдельным виджетом.
23. Как пользователь Signal Grid или Titanium Chrono, я хочу видеть mono только для измерений, чтобы сохранить характер Instrument Grid.
24. Как пользователь System, Color, Prism, Swiss, Deadline Ledger или Monochrome, я хочу, чтобы погодная типографика наследовала системный или serif характер темы.
25. Как пользователь со включённым Reduce Motion, я не хочу анимированную прокрутку или переходы, которые игнорируют настройку доступности.
26. Как пользователь VoiceOver, я хочу получить один полный label для периода: время, температура, влажность и вероятность осадков.
27. Как пользователь русской или английской локали, я хочу видеть локализованные подписи и формат времени.

## Implementation Decisions

- Источник — Open-Meteo Forecast API и Open-Meteo Geocoding API. У интеграции нет ключа; UI зависит от собственного vendor-neutral protocol, а не от Open-Meteo types.
- HTTP transport остаётся отдельным Sendable seam на основе существующего `HTTPDataLoader`; тесты не используют сеть.
- Модели места, настроек, forecast points, cache metadata, provider errors и interval enum живут в `QuickCalKit`, являются Codable/Sendable и имеют версионированные ключи `UserDefaults`.
- Выбранное место хранит display name, административные части, country code, latitude и longitude. Последнее успешно automatic-определённое место записывается тем же форматом и может стать fallback.
- Core Location используется только в application layer. Никакой location request на запуске или при открытии popover: запрос вызывается только из явного включения automatic mode.
- `WeatherController` в application layer владеет foreground 30-minute timer, permission state, refresh task, кешированным UI state и lifecycle. Он не запускает приложение из закрытого состояния.
- Forecast request получает UTC/Unix timestamps и hourly fields `temperature_2m`, `relative_humidity_2m`, `precipitation_probability`, `weather_code`. Display periods выбираются по хронологическому порядку абсолютных timestamp; подписи, day/night symbol и доступные labels форматируются в `TimeZone.autoupdatingCurrent`.
- Горизонт provider response — не меньше 48 часов. UI строит start range от ближайшей актуальной точки и выбирает точки с выбранным шагом 2/4/8/12 часов.
- Initial viewport имеет ровно четыре равной ширины periods, без видимого куска пятого. Правая/левая стрелки являются overlay над scroll area и зависят от фактической scroll position.
- Периоды избранных календарных дат не меняются: `SelectedDatesStore` и существующая связная отрисовка диапазона остаются source of truth. Weather UI не рисует и не меняет selected dates.
- Weather rail использует существующие `QuickCalThemeStyle` tokens: primary/secondary text, divider, selection и surface. Для информативного 10pt микротекста Color Light применяется существующий primaryText из-за контраста secondaryText на composited panel.
- Mono для weather measurements допустим только у Instrument Grid; остальные grammar наследуют system/rounded или New York serif typography темы.
- В options popup добавляются Weather visibility, location search, automatic location, interval. При visibility off зависимые Weather controls не активны и скрыты.
- Fresh result моложе 30 минут отображается без stale marker. Между 30 минутами и 24 часами используется cached forecast с «Обновлено …» и manual refresh. Старше 24 часов — unavailable state. Ошибки не стирают валидный stale cache.
- Для weather code реализуется единая локальная mapping table к SF Symbols с day/night variant, без emoji.

## Testing Decisions

- Unit tests проверяют публичное поведение provider client: HTTPS validation, URL/query contract, non-2xx, decode, UTC timestamps и нормализацию hourly arrays.
- Unit tests проверяют persistence settings и locations: decode invalid data, versioned defaults, manual/automatic fallback и interval values.
- Unit tests проверяют forecast grouping: локальный часовой пояс Mac, четыре начальных периода, шаги 2/4/8/12, отсутствие частичного пятого period и границы стрелок.
- Unit tests `WeatherController` используют injected clock, location service и provider, проверяют 30-minute refresh, stale 24-hour policy, manual refresh, permission denial и отсутствие request до включения automatic mode.
- SwiftUI rendering tests используют existing theme rendering seam, проходят все 16 `QuickCalTheme` и подтверждают grammar-specific typefaces, tokens, weather visibility и unchanged selected-date segment behavior.
- Model/UI tests проверяют labels period, buttons, selected interval и отсутствие colour-only semantics; ручная smoke-проверка подтверждает интерактивные scroll arrows и options popup.

## Out of Scope

- Деплой, облачная синхронизация или background launch QuickCal, когда приложение не запущено.
- Уведомления о погоде, daily forecast, severe-weather alerts, radar и прогноз ветра.
- Яндекс.Погода или Gismeteo adapter на первом этапе.
- Платный weather provider, API keys и сторонняя аналитика.
- Изменение существующей логики производственного календаря или selected dates.

## Further Notes

- Макет и тема handoff находятся вне репозитория: `/Users/andrei.lukyantsev/.codex/visualizations/2026/08/07/019fdcd9-2097-7003-8906-ab692c41871f/weather-handoff/`.
- Решения пользователя: no automatic request on first launch; refresh and automatic location every 30 minutes while app runs; manual location uses geocoded concrete result; stale cache up to 24 hours; last automatic/manual location fallback; no weather block when no location; displayed time follows Mac local timezone.
