# safe-wheel

Wails-приложение (Go + фронтенд), управление конкурсами «Безопасное колесо».

## Проверка

- `go build ./... && go vet ./... && go test ./...`
- Фронтенд: `cd frontend && npm run build`
- Dev: `lota dev` (или `wails dev -tags webkit2_41`)

## Windows-сборка (Win7/8.1 поддержка)

- `lota build windows|nsis` и CI собирают exe пропатченным тулчейном
  go-legacy-win7 (`scripts/ensure-legacy-go.sh`, pinned sha256): официальный
  Go ≥1.21 не запускается на Win7/8.1 (ProcessPrng, PE subsystem 6.4+).
- `build/windows/installer/project.nsi` не вызывает `wails.checkArchitecture`
  (там жёсткий `AtLeastWin10`); проверяется только amd64.
- Целевые машины обычно без интернета, поэтому вместо evergreen bootstrapper'а
  инсталлятор кладёт bundled fixed-version WebView2 **v109** (последняя
  совместимая с Win7/8.1) в `$INSTDIR\webview2` — но только если в реестре нет
  установленного рантайма. `main.go` указывает на него через
  `Windows.WebviewBrowserPath`. Рантайм скачивается при сборке скриптом
  `scripts/fetch-webview2-runtime.sh` (pinned sha256, нужен cabextract/7z).
