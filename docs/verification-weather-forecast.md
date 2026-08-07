# Проверка weather forecast

Этот документ фиксирует контракт функции погоды для release-приёмки.

## Lifecycle и consent

- `QuickCalAppDelegate` создаёт один `WeatherController` при запуске menu bar
  приложения, передаёт его в `CalendarPopoverView` и сразу запускает
  foreground refresh; открытие popover не является триггером обновления.
- Контроллер планирует очередные refresh через 30 минут, пока QuickCal запущен.
  В `applicationWillTerminate` timer invalidated; приложение не делает
  background launch после штатного завершения.
- Initial refresh в manual/default mode не вызывает Core Location. Системный
  запрос доступен только через явное включение automatic location в настройках.
- `NSLocationWhenInUseUsageDescription` поставляется в `QuickCal.app` и
  объясняет, что геолокация используется только после включения automatic
  weather location.

## Data contract

- Provider: Open-Meteo Forecast и Geocoding API по HTTPS без API key.
- В forecast запрашиваются `temperature_2m`, `relative_humidity_2m`,
  `precipitation_probability` и `weather_code`; timestamps приходят как UTC
  Unix time.
- UI переводит instant в `TimeZone.autoupdatingCurrent`: прогноз для Москвы
  остаётся московским по данным, но его подписи показываются в локальном
  часовом поясе Mac.
- Кеш действует до 24 часов; свежий интервал и foreground refresh равны
  30 минутам. При ошибке сохраняется валидный stale cache и последнее
  automatic/manual место служит fallback.

## Канонические проверки

```bash
./Scripts/test.sh
./Scripts/build-app.sh
```

`Scripts/test.sh` включает shell regression test build script, Swift Testing и
проверку непустого xUnit. Build-script suite дополнительно извлекает
`NSLocationWhenInUseUsageDescription` из готового `QuickCal.app`, поэтому
наличие privacy key проверяется в артефакте, а не только в исходном plist.
