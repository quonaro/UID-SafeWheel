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
  (там жёсткий `AtLeastWin10`); проверяется только архитектура CPU.
- Целевые машины обычно без интернета, поэтому вместо evergreen bootstrapper'а
  инсталлятор кладёт bundled fixed-version WebView2 **v109** (последняя
  совместимая с Win7/8.1) в `$INSTDIR\webview2` — но только если в реестре нет
  установленного рантайма. `main.go` указывает на него через
  `Windows.WebviewBrowserPath`. Рантайм скачивается при сборке скриптом
  `scripts/fetch-webview2-runtime.sh <x64|x86>` (pinned sha256, нужен
  cabextract/7z) в `build/windows/installer/webview2/<arch>/`.

## 32-битные сборки

- `lota build windows32` — exe `windows/386` (тот же пропатченный тулчейн;
  PE subsystem 6.01, проверено `objdump`).
- `lota build nsis32` — `scripts/build-nsis-386.sh`: собирает 386-exe, кладёт
  x86-рантайм WebView2 v109 и компилирует инсталлятор **прямым вызовом
  makensis** на `build/windows/installer/project-386.nsi`, потому что
  `wails build -nsis` умеет только amd64/arm64 (amd64Binary/arm64Binary в
  `cmd/wails/build.go`, `wails_tools.nsh` знает лишь `ARG_WAILS_*_BINARY`).
  `project-386.nsi` задаёт `INSTALLER_ARCH=386` и переиспользует
  `project.nsi`; в 386-режиме `wails.files` не вызывается, exe кладётся через
  `File` напрямую.
- 386-инсталлятор принимает IA32 **или** AMD64 (32-битный exe работает под
  WOW64); проверка WebView2 в реестре дополнительно смотрит путь без
  `WOW6432Node` (на 32-битной Windows его нет).
- `lota build linux32` — `scripts/build-linux-386.sh`: linux/386 **не входит**
  в список платформ wails, поэтому бинарь собирается вручную в контейнере
  `i386/debian:bookworm-slim` (`go build -tags desktop,production,webkit2_41`
  + pinned Go linux-386 tarball). Требует уже собранных `frontend/dist` и
  `frontend/wailsjs` (запустить `lota build linux` первым); AppImage для 386
  не делается — linuxdeploy не поставляет i386.
- Обе 32-битные сборки в CI (`.github/workflows/release.yml`) идут после
  соответствующих amd64-шагов, которые готовят биндинги/фронтенд.
