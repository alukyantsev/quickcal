# QuickCal: источники котировок MOEX ISS

Дата исследования: 8 августа 2026 года
Дата live-проверки ISS: 8 августа 2026 года

## Вывод

Для QuickCal нужно различать три класса источников:

1. **Прямой индекс или спот** — лучший вариант, когда он действительно доступен: `USD000UTSTOM`, `EUR_RUB__TOM`, `EURUSD000TOM`, `IMOEX`, `RTSI`, `MOEXBTC`, `GLDRUB_TOM`.
2. **Вечный (однодневный с автопролонгацией) фьючерс** — удобен для отображения, так как нет роллирования: `USDRUBF`, `EURRUBF`, `IMOEXF`, `SP500F`, `GLDRUBF`.
3. **Срочный фьючерс с датой исполнения** — нужен для EUR/USD, Brent и части мировых активов; приложение должно находить ближайшую неистёкшую серию по `ASSETCODE` и `LASTTRADEDATE`, а не зашивать код месяца.

Один и тот же JSON-блок `marketdata` имеет разные поля: у прямых индексов цена — `CURRENTVALUE`, абсолютное изменение — `LASTCHANGE`, процент — `LASTCHANGEPRC`; у срочных и вечных фьючерсов цена — `LAST`, дневной процент — `LASTTOPREVPRICE`. Это нужно учитывать в адаптере, а не пытаться читать все инструменты как акции.

## Универсальный ISS-шаблон

Для отдельного инструмента:

```
https://iss.moex.com/iss/engines/{engine}/markets/{market}/securities/{SECID}.json
  ?iss.meta=off
  &iss.only=securities,marketdata
```

Для текущей серии срочного фьючерса сначала загружается каталог:

```
https://iss.moex.com/iss/engines/futures/markets/forts/securities.json
  ?iss.meta=off
  &iss.only=securities
  &securities.columns=SECID,SHORTNAME,ASSETCODE,LASTTRADEDATE
```

Затем выбирается ближайший неистёкший контракт нужного `ASSETCODE`.

## Валюты

| Что показать | Подтверждённый вариант | ISS path | Масштаб цены | Другие варианты и решение |
|---|---|---|---|---|
| USD/RUB | CETS TOM: `USD000UTSTOM` | `engines/currency/markets/selt/securities/USD000UTSTOM.json` | рубли за 1 USD; live `LAST=82.6675` | Это прямой спот-курс. Вечный фьючерс `USDRUBF` — допустимая отдельная фьючерсная котировка. Срочная серия `Si` имеет лот 1 000 USD и требует деления на 1 000. Рекомендация: для «USD/RUB» по умолчанию использовать TOM. |
| EUR/RUB | CETS TOM: `EUR_RUB__TOM` | `engines/currency/markets/selt/securities/EUR_RUB__TOM.json` | рубли за 1 EUR; в момент проверки `LAST` пуст, `MARKETPRICE2=94.8366` | Это прямой спот-курс. Вечный `EURRUBF` — отдельная фьючерсная котировка. Срочная серия `Eu` требует деления на 1 000. Рекомендация: для «EUR/RUB» по умолчанию TOM с fallback `LAST → MARKETPRICE2`. |
| EUR/USD | CETS TOM: `EURUSD000TOM` | `engines/currency/markets/selt/securities/EURUSD000TOM.json` | USD за 1 EUR; в момент проверки `LAST` пуст, `MARKETPRICE2=1.1542` | Это семантически лучший прямой курс. Квартальный `ED` (8 августа `EDU6`, `1.1543`) — отдельный фьючерс. Рекомендация: для «EUR/USD» по умолчанию TOM с fallback `LAST → MARKETPRICE2`. |

MOEX документирует `Si` как USD/RUB, `Eu` как EUR/RUB, `ED` как EUR/USD; у `ED` котировка — USD за один евро. [Параметры валютных фьючерсов MOEX](https://www.moex.com/a7235)
MOEX также публикует вечные USD/RUB и EUR/RUB как `USDRUBF` и `EURRUBF`. [Презентация вечных валютных фьючерсов](https://fs.moex.com/f/16559/prezentacija-vechnyy-fjuchers-en.pdf)

### Важное правило для CETS

У прямых валютных пар SECID не равен короткому названию. Необходимо использовать `USD000UTSTOM`, `EUR_RUB__TOM` и `EURUSD000TOM`, а не исторически очевидные `USDRUB_TOM`/`EURRUB_TOM`. В неактивную торговую сессию у CETS `LAST` может отсутствовать; fallback — `MARKETPRICE2`, а дата снимка берётся из `SYSTIME`/рыночных полей ответа. Дневной процент не следует подменять нулём, если на fallback-цене он не вычислен.

## Российские индексы

| Что показать | Прямой источник | ISS path | Альтернатива | Рекомендация |
|---|---|---|---|---|
| Индекс МосБиржи | `IMOEX` | `engines/stock/markets/index/securities/IMOEX.json` | `IMOEXF` — вечный фьючерс; квартальные `MIX` и мини `MXI` | Для сводки показывать прямой `IMOEX`: это значение индекса без фьючерсного базиса. |
| Индекс РТС | `RTSI` | `engines/stock/markets/index/securities/RTSI.json` | квартальный `RTS` (`RIU6`), мини `RTSM` (`RMU6`) | Для сводки показывать прямой `RTSI`; он рассчитывается в USD. |

Live-проверка: `IMOEX` вернул `CURRENTVALUE=2281.31`, `RTSI` — `CURRENTVALUE=874.64`; `IMOEXF` вернул `LAST=2268`. Вечный `IMOEXF` котируется в пунктах индекса и не требует роллирования, но содержит фьючерсный базис и фандинг. [Параметры IMOEXF](https://www.moex.com/a8803)
MOEX прямо указывает валюты расчёта: IMOEX — рубль, RTSI — доллар США. [Параметры индексов акций MOEX](https://www.moex.com/n98601)

## Мировые активы и сырьё

| Что запросил пользователь | Подтверждённый вариант в MOEX ISS | Тип и важное ограничение | Рекомендация для QuickCal |
|---|---|---|---|
| S&P 500 | `SP500F`: `engines/futures/markets/forts/securities/SP500F.json`; также срочная серия `SPYF` (например, `SFU6`) | **Не прямой S&P 500**: базис — фиксинг MOEX SPY ETF (`FIXSPY`), то есть ETF-прокси | Можно добавить как «S&P 500 (SPY ETF)», не называть просто «S&P 500». |
| Золото, USD | ближайшая серия `GOLD` (на дату проверки `GDU6`) | срочный фьючерс, нужна динамическая серия; live: `4350.8` | Добавлять как «Gold futures, USD/oz» только после проверки единицы в контракте на выбранной серии. |
| Золото, RUB | `GLDRUB_TOM`: `engines/currency/markets/selt/boards/CETS/securities/GLDRUB_TOM.json`; альтернативно `GLDRUBF` | прямой спот золота в RUB за грамм; `GLDRUBF` — вечный фьючерс | Лучший локальный вариант — `GLDRUB_TOM`; подписать «Золото, ₽/г». |
| Brent | ближайшая серия `BR` (на дату проверки `BRU6`) | срочный фьючерс, нужна динамическая серия; live: `82.70` | Добавить как «Brent, USD/bbl». Для компактной сводки выбирать ближайший неистёкший `BR`. |
| Urals | активный источник в MOEX ISS **не подтверждён** | Найдена только архивная спецификация Urals; текущий каталог фьючерсов не дал современную подтверждённую серию | Не добавлять через MOEX до отдельной проверки/внешнего лицензированного источника. |
| Bitcoin | прямой `MOEXBTC`: `engines/stock/markets/index/securities/MOEXBTC.json`; срочная серия `BTC` (на дату проверки `BTU6`) | `MOEXBTC` — индекс MOEX, а не торговая пара конкретной криптобиржи; live: `64970.92` | Для обычного виджета предпочесть прямой `MOEXBTC`, подпись «Bitcoin (индекс MOEX)». |

`SP500F` запущен как вечный контракт на фиксинг MOEX SPY ETF, а не на сам S&P 500. [MOEX: запуск SP500F](https://www.moex.com/n102837)
MOEX описывает Bitcoin Index `MOEXBTC` как взвешенный индикатор по perpetual futures и swap BTCUSDT нескольких криптобирж. [Методологическое описание запуска MOEXBTC](https://www.moex.com/n90959)
Для Brent MOEX указывает базовый актив Brent, размер лота 10 баррелей и месячные серии. [Параметры Brent futures](https://fs.moex.com/files/19815)
Для золота MOEX подтверждает спот `GLDRUB_TOM` и лот 1 грамм; котировка в рублях. [Параметры рынка драгметаллов](https://www.moex.com/n100358)
Упоминание Urals находится только в архиве спецификаций MOEX, поэтому не является подтверждением торгуемого сейчас инструмента. [Архив спецификаций](https://www.moex.com/a1906)

## Предлагаемый набор для следующей версии

### Сделать дефолтными базовыми курсами

- `USD000UTSTOM` → «USD/RUB»;
- `EUR_RUB__TOM` → «EUR/RUB»;
- `EURUSD000TOM` → «EUR/USD»;
- `IMOEX` → «IMOEX».

### Добавлять без внешнего провайдера

- `USDRUBF`, `EURRUBF`, динамический `ED` — как явные фьючерсные альтернативы;
- `RTSI` → «RTS»;
- `MOEXBTC` → «Bitcoin (MOEX)»;
- ближайший `BR` → «Brent»;
- `GLDRUB_TOM` → «Gold ₽/g»;
- опционально `SP500F` → «S&P 500 (SPY ETF)».

### Не добавлять пока

- Urals — нет подтверждённого актуального live-инструмента;
- «чистый» S&P 500 — MOEX-альтернатива является ETF-прокси;
- квартальные `Si`, `Eu`, `MIX`, `RTS` в UI по умолчанию — требуют roll logic, а часть ещё и преобразования масштаба цены.

## Техническое правило для реализации

Не расширять текущий `route(for:)` строковыми путями для срочных контрактов. Нужен каталог инструмента:

- `assetCode`: `ED`, `BR`, `GOLD`, `BTC`;
- правило выбора: ближайший `LASTTRADEDATE >= now`, иначе последний доступный;
- `priceScale`: `1` для `ED`, `BR`, `GOLD`, `BTC`; `1_000` для серий `Si` и `Eu`;
- формат: `CURRENTVALUE` для индексов, `LAST` для FORTS, `LAST → MARKETPRICE2` для CETS;
- показывать в UI тип источника, когда это прокси: «S&P 500 (SPY ETF)», «Bitcoin (индекс MOEX)».
