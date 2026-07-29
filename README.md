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

Скрипт сначала собирает приложение с default macOS SDK, выбранным `xcrun`. Если
такая сборка не проходит, он проверяет соседние установленные `MacOSX*.sdk`
минимальным `swiftc -typecheck` probe и повторяет сборку с первым совместимым
SDK. Чтобы использовать конкретный SDK без автоматического fallback, задайте
его явно:

```bash
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)" ./Scripts/build-app.sh
```

## Установка

Скопируйте `dist/QuickCal.app` в `/Applications`, затем откройте его. Запуск из
`/Applications` нужен для штатной регистрации опции «Запускать при входе».

## Удаление

Сначала выключите «Запускать при входе» внутри QuickCal и завершите приложение,
затем удалите `/Applications/QuickCal.app`.
