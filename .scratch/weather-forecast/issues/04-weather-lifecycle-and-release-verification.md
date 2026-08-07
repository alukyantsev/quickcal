# 04 — Lifecycle и release verification погоды

**What to build:** QuickCal запускает weather refresh lifecycle вместе с menu bar app, корректно объясняет доступ к location и поставляет подтверждённую интеграцию без регрессий календаря.

**Blocked by:** 03 — Погодная лента и настройки во всех темах.

**Status:** done

- [x] App lifecycle запускает и останавливает foreground refresh без background launch из закрытого состояния.
- [x] macOS location usage description и runtime behaviour соответствуют automatic-only consent.
- [x] Full test suite проходит; тесты подтверждают все 16 тем, no-location, stale/error и persistent fallback.
- [x] Документация и verification evidence описывают Open-Meteo contract и пользовательские решения.
