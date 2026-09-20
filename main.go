package main

import (
	"embed"
	"log/slog"
	"os"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/linux"
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
