package main

import (
	"embed"
	"log/slog"
	"os"
	"path/filepath"
	"runtime"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/linux"
	"github.com/wailsapp/wails/v2/pkg/options/windows"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	slog.SetDefault(slog.New(newColorHandler(os.Stderr, slog.LevelDebug)))

	slog.Info("starting SafeWheel")

	// WebKitGTK's DMA-BUF renderer crashes on Wayland (Error 71 protocol error).
	// Disable it; still overridable from the environment for testing.
	if _, ok := os.LookupEnv("WEBKIT_DISABLE_DMABUF_RENDERER"); !ok {
		_ = os.Setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1")
	}

	// Target Windows machines often have no internet, so the NSIS installer
	// unpacks a bundled fixed-version WebView2 v109 runtime into
	// <exe>\webview2 when no system runtime is installed. Point the loader at
	// it; an empty path keeps normal system-runtime detection.
	webviewBrowserPath := ""
	if runtime.GOOS == "windows" {
		if exe, err := os.Executable(); err == nil {
			dir := filepath.Join(filepath.Dir(exe), "webview2")
			if st, err := os.Stat(filepath.Join(dir, "msedgewebview2.exe")); err == nil && !st.IsDir() {
				webviewBrowserPath = dir
			}
		}
	}

	// Create an instance of the app structure
	app := NewApp()

	// Create application with options
	err := wails.Run(&options.App{
		Title:     "Безопасное колесо",
		Width:     1280,
		Height:    720,
		MinWidth:  1280,
		MinHeight: 720,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 250, G: 250, B: 250, A: 1},
		Linux: &linux.Options{
			WebviewGpuPolicy: linux.WebviewGpuPolicyAlways,
		},
		Windows: &windows.Options{
			WebviewBrowserPath: webviewBrowserPath,
		},
		OnStartup:  app.startup,
		OnShutdown: app.shutdown,
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		slog.Error("wails run failed", "error", err)
	}
}
