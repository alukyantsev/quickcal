# 03 — Погодная лента и настройки во всех темах

**What to build:** Пользователь видит и использует постоянно раскрытую погодную ленту, меняет место и интервалы, отключает блок и получает одинаковую функциональность во всех 16 темах без нарушения календарных selected ranges.

**Blocked by:** 02 — Обновление прогноза и automatic location.

**Status:** done

- [x] Initial viewport показывает ровно четыре периода; при скролле доступны дальнейшие прогнозы и корректные левая/правая стрелки.
- [x] Время периодов отображается в локальном часовом поясе Mac после UTC conversion, не в часовом поясе выбранного места.
- [x] Settings popup содержит weather visibility, location search, automatic mode, интервалы 2/4/8/12 и manual refresh для stale/error.
- [x] Weather typography, tokens и surfaces наследуют каждую grammar; selected calendar dates сохраняют текущую связанную отрисовку.
- [x] Accessibility labels, Reduce Motion и ru/en strings покрывают weather interactions.
