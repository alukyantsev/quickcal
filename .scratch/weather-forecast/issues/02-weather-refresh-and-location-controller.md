# 02 — Обновление прогноза и automatic location

**What to build:** Пока QuickCal запущен, прогноз обновляется каждые 30 минут; automatic location запрашивает разрешение только после явного включения и надёжно использует fallback место.

**Blocked by:** 01 — Погодные модели, кеш и Open-Meteo provider.

**Status:** done

- [ ] Контроллер не делает location request на запуске и при открытии popover.
- [ ] После явного включения automatic mode определяет место, сохраняет его и обновляет location/forecast раз в 30 минут.
- [ ] Refesh, stale cache до 24 часов, manual refresh, permission denial и no-location state имеют проверяемое поведение.
- [ ] Timer, clock, location service и provider подменяемы в тестах.
