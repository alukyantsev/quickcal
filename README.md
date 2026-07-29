# QuickCal

QuickCal — локальный календарь для строки меню macOS на Apple Silicon.

## Требования

- macOS 14 или новее;
- Apple Silicon (`arm64`);
- Swift 6 command line tools.

## Сборка

```bash
./Scripts/build-app.sh
```

Готовое приложение появится в `dist/QuickCal.app`.

## Установка

Скопируйте `dist/QuickCal.app` в `/Applications`, затем откройте его. Запуск из
`/Applications` нужен для штатной регистрации опции «Запускать при входе».

## Удаление

Сначала выключите «Запускать при входе» внутри QuickCal и завершите приложение,
затем удалите `/Applications/QuickCal.app`.
