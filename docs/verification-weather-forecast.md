# Проверка прогноза погоды и котировок MOEX

Этот документ фиксирует контракт сетевых функций QuickCal для release-приёмки.

## Lifecycle и consent

- `QuickCalAppDelegate` создаёт один `WeatherController` и один
  `ForegroundRefreshCoordinator` при запуске menu bar приложения, передаёт
  контроллеры и coordinator в `CalendarPopoverView` и сразу запускает
  foreground refresh; открытие popover не является триггером обновления.
- Только `ForegroundRefreshCoordinator` планирует очередные refresh через 30
  минут, пока QuickCal запущен.
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

## Котировки MOEX

- Provider — официальный MOEX ISS по HTTPS без ключа. Поддерживаются акции
  MOEX основного режима, `IMOEX`, вечные фьючерсы `USDRUBF`/`EURRUBF` и прямой
  фьючерс `EUR/USD`; активный EUR/USD-контракт выбирается по данным ISS.
- Настройки и последний успешный snapshot сохраняются локально. Кеш котировок
  пригоден максимум семь календарных дней; по истечении срока UI показывает
  недоступность вместо старой цены. Закрытая сессия не ошибка: видны последние
  строки и дата только из полей `marketdata` ISS (`TRADEDATE`,
  `TRADE_SESSION_DATE` или `SYSTIME`). Если ISS не отдала ни одного из них,
  UI явно сообщает, что дата недоступна; срок инструмента и время загрузки для
  этого не используются.
- `ForegroundRefreshCoordinator` владеет единым foreground timer раз в 30 минут
  и обновляет weather и quotes одновременно. В header показывается время
  завершения этого общего цикла, а частичные ошибки остаются видимыми в блоках.
  Ручной retry делает то же самое.
- При ошибке сети fallback-кеш котировок фильтруется и упорядочивается по
  текущему watchlist, поэтому удалённые тикеры не возвращаются в интерфейс.
- Функция котировок выключена по умолчанию, а дефолтный список сохраняется:
  `USDRUBF, EURRUBF, EUR/USD, IMOEX`. Нормализация ввода удаляет пробелы и
  дубли, приводит алиасы/регистр к каноническим идентификаторам и сохраняет
  порядок.
- В строке доступны имя, цена, знак/стрелка/цвет изменения и процент. VoiceOver
  дополнительно получает направление словами, абсолютное изменение и дату;
  все новые строки и labels локализованы на русском и английском. Quote rail не
  вводит собственных анимаций, поэтому Reduce Motion не меняет его состояние.
- Quote rail использует цвета, divider и типографику активной темы; release
  fixture покрывает все темы, включая семейства Native Toolbar, Deadline Ledger
  и Instrument Grid.

## Канонические проверки

```bash
./Scripts/test.sh
./Scripts/build-app.sh
```

`Scripts/test.sh` включает shell regression test build script, Swift Testing и
проверку непустого xUnit. Build-script suite дополнительно извлекает
`NSLocationWhenInUseUsageDescription` из готового `QuickCal.app`, поэтому
наличие privacy key проверяется в артефакте, а не только в исходном plist.
