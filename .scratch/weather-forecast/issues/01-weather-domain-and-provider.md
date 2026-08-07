# 01 — Погодные модели, кеш и Open-Meteo provider

**What to build:** QuickCal умеет хранить выбранное место и настройки погоды, получать нормализованный почасовой прогноз Open-Meteo без ключа и безопасно читать сохранённый кеш.

**Blocked by:** None — can start immediately.

**Status:** done

- [ ] Место хранит display name, coordinates и country context; settings включают visibility, location mode и интервалы 2/4/8/12.
- [ ] Provider получает geocoded concrete location и нормализует UTC почасовые temperature, humidity, precipitation probability и weather code.
- [ ] Network, decode и invalid-cache errors проверены через injected transport без настоящей сети.
- [ ] Сохранённые settings/cache переживают перезапуск и не падают на невалидных данных.
