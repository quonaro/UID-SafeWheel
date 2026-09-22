####
## 32-bit (x86) variant of the SafeWheel installer.
##
## `wails build -nsis` only produces installers for amd64/arm64 binaries, so
## this file is compiled by invoking makensis on it directly (see
## scripts/build-nsis-386.sh, `lota build nsis32` and the CI release job):
##
##   cd build/windows/installer && makensis project-386.nsi
##
## wails_tools.nsh refuses to compile without an ARG_WAILS_*_BINARY define;
## the one below points at the built 32-bit exe, which project.nsi files
## directly when INSTALLER_ARCH == "386" (wails.files is not used).
####

Unicode true

!define INSTALLER_ARCH "386"
!define ARG_WAILS_AMD64_BINARY "..\..\bin\safe-wheel-windows-386.exe"

!include "project.nsi"
