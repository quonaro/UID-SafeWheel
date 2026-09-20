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
- WebView2 на Win7/8.1 ставит evergreen bootstrapper — он автоматически
  разворачивает v109 (последняя совместимая версия).
