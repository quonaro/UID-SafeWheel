Unicode true

####
## Custom NSIS installer for SafeWheel.
## Wails uses this file instead of the default template when it exists at
## build/windows/installer/project.nsi. The wails_tools.nsh include provides
## all standard macros (wails.files, wails.writeUninstaller, etc.).
####

# Per-user install into $LOCALAPPDATA\Programs: no admin rights/UAC required.
# wails_tools.nsh defaults REQUEST_EXECUTION_LEVEL and WAILS_INSTALL_SCOPE to
# admin/machine, so define them here (before the include) to force a per-user
# installer even when `wails build -nsis` is run without -installscope user.
# An explicit `-installscope machine` on the command line still wins
# (command-line defines are processed before this script).
!ifndef REQUEST_EXECUTION_LEVEL
    !define REQUEST_EXECUTION_LEVEL "user"
!endif
!ifndef WAILS_INSTALL_SCOPE
    !define WAILS_INSTALL_SCOPE "user"
!endif

# INSTALLER_ARCH is defined by project-386.nsi for the 32-bit build
# (wails build -nsis only supports amd64/arm64, so the x86 installer is
# compiled by invoking makensis on project-386.nsi directly).
!ifndef INSTALLER_ARCH
    !define INSTALLER_ARCH "amd64"
!endif
!if "${INSTALLER_ARCH}" == "386"
    !define WEBVIEW2_SRC "webview2\x86"
!else
    !define WEBVIEW2_SRC "webview2\x64"
!endif

!include "wails_tools.nsh"

# The version information for this two must consist of 4 parts
VIProductVersion "${INFO_PRODUCTVERSION}.0"
VIFileVersion    "${INFO_PRODUCTVERSION}.0"

VIAddVersionKey "CompanyName"     "${INFO_COMPANYNAME}"
VIAddVersionKey "FileDescription" "${INFO_PRODUCTNAME} Installer"
VIAddVersionKey "ProductVersion"  "${INFO_PRODUCTVERSION}"
VIAddVersionKey "FileVersion"     "${INFO_PRODUCTVERSION}"
VIAddVersionKey "LegalCopyright"  "${INFO_COPYRIGHT}"
VIAddVersionKey "ProductName"     "${INFO_PRODUCTNAME}"

# Enable HiDPI support.
ManifestDPIAware true

!include "MUI2.nsh"
!include "WinMessages.nsh"

!define MUI_ICON "..\icon.ico"
!define MUI_UNICON "..\icon.ico"
!define DISPLAY_NAME "ЮИД Безопасное колесо"
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_WELCOMEPAGE_TITLE "Вас приветствует мастер установки ${DISPLAY_NAME} ${INFO_PRODUCTVERSION}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Russian"

Name "${DISPLAY_NAME}"
Caption "Установка ${DISPLAY_NAME} ${INFO_PRODUCTVERSION}"
BrandingText " "
OutFile "..\..\bin\safe-wheel-windows-${INSTALLER_ARCH}-installer.exe"
InstallDir "$LOCALAPPDATA\Programs\${INFO_PRODUCTNAME}"
ShowInstDetails show

Function .onInit
   !insertmacro wails.setShellContext

   # Windows 7 SP1 / 8.1 are supported targets (WebView2 v109 + patched Go
   # toolchain). wails.checkArchitecture would abort on anything below
   # Windows 10, so only the CPU architecture is checked here.
   !if "${INSTALLER_ARCH}" == "386"
       # The 32-bit build also runs on 64-bit Windows via WOW64.
       ${ifnot} ${IsNativeIA32}
       ${andifnot} ${IsNativeAMD64}
           IfSilent silentArch notSilentArch
           silentArch:
               SetErrorLevel 65
               Abort
           notSilentArch:
               MessageBox MB_ICONSTOP "Для установки требуется Windows на процессоре x86 или x64."
               Quit
       ${endif}
   !else
       ${ifnot} ${IsNativeAMD64}
           IfSilent silentArch notSilentArch
           silentArch:
               SetErrorLevel 65
               Abort
           notSilentArch:
               MessageBox MB_ICONSTOP "Для установки требуется 64-разрядная версия Windows."
               Quit
       ${endif}
   !endif
FunctionEnd

Section
    # Target machines usually have no internet, so the evergreen bootstrapper
    # (wails.webview2runtime) cannot help there. When no WebView2 runtime is
    # installed, unpack the bundled fixed-version v109 (the last Win7/8.1-
    # compatible release, fetched by scripts/fetch-webview2-runtime.sh) next
    # to the exe; main.go points WebviewBrowserPath at it.
    SetRegView 64
    ReadRegStr $0 HKLM "SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
    ${If} $0 == ""
        # 32-bit Windows has no WOW6432Node; the runtime registers in the
        # plain view there (SetRegView is a no-op on x86).
        ReadRegStr $0 HKLM "SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
    ${EndIf}
    ${If} $0 == ""
        ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
    ${EndIf}
    ${If} $0 == ""
        DetailPrint "Installing bundled WebView2 Runtime v109"
        SetOutPath "$INSTDIR\webview2"
        File /r "${WEBVIEW2_SRC}\*"
    ${Else}
        # A system runtime exists: drop a bundled copy left by a previous
        # install so the app uses the shared auto-updating runtime.
        RMDir /r "$INSTDIR\webview2"
    ${EndIf}

    SetOutPath $INSTDIR

    !if "${INSTALLER_ARCH}" == "386"
        # wails.files only knows the amd64/arm64 defines; the 386 build passes
        # its exe via ARG_WAILS_AMD64_BINARY purely to satisfy wails_tools.nsh,
        # so file the binary directly here.
        File "/oname=${PRODUCT_EXECUTABLE}" "${ARG_WAILS_AMD64_BINARY}"
    !else
        !insertmacro wails.files
    !endif

    # 1. Desktop shortcut
    CreateShortCut "$DESKTOP\${DISPLAY_NAME}.lnk" "$INSTDIR\${PRODUCT_EXECUTABLE}"

    # 2. Start Menu shortcut
    CreateShortcut "$SMPROGRAMS\${DISPLAY_NAME}.lnk" "$INSTDIR\${PRODUCT_EXECUTABLE}"

    !insertmacro wails.writeUninstaller
SectionEnd

Function un.onInit
   SetShellVarContext current
FunctionEnd

Section "uninstall"
    # Remove shortcuts
    Delete "$DESKTOP\${DISPLAY_NAME}.lnk"
    Delete "$SMPROGRAMS\${DISPLAY_NAME}.lnk"

    # Remove WebView2 data
    RMDir /r "$AppData\${PRODUCT_EXECUTABLE}"

    # Remove the bundled fixed-version runtime
    RMDir /r "$INSTDIR\webview2"

    # Remove only the executable and uninstaller; preserve safewheel.db
    Delete "$INSTDIR\${PRODUCT_EXECUTABLE}"
    Delete "$INSTDIR\uninstall.exe"

    !insertmacro wails.deleteUninstaller
SectionEnd
