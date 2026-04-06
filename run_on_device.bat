@echo off
REM Build, install, and launch donish_app on connected Android device.
REM Windows: turn ON Developer Mode (symlinks) or "flutter build apk" fails — Settings - For developers.
set "FLUTTER=%USERPROFILE%\flutter_sdk\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\Users\user\flutter_sdk\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\Users\SARDOR\Downloads\flutter_windows_3.41.4-stable\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" (
  echo Flutter not found. Clone or install Flutter, or edit FLUTTER in this script.
  echo Example: git clone https://github.com/flutter/flutter.git -b stable --depth 1 "%USERPROFILE%\flutter_sdk"
  exit /b 1
)
REM Prefer project-local platform-tools if present (SDK copy of adb.exe can hang on some PCs).
set "ADB=%~dp0_platform-tools-new\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo adb not found. Install Android platform-tools or extract platform-tools-latest-windows.zip to _platform-tools-new\platform-tools\
  exit /b 1
)
set "APK=%~dp0build\app\outputs\flutter-apk\app-debug.apk"

cd /d "%~dp0"
echo Using Flutter: %FLUTTER%
echo Using adb:    %ADB%
echo.
echo Building debug APK...
call "%FLUTTER%" build apk --debug
if errorlevel 1 exit /b 1

echo.
echo Installing on device...
"%ADB%" install -r "%APK%"
if errorlevel 1 exit /b 1

echo.
echo Launching app...
"%ADB%" shell am start -n uz.donish/uz.donish.MainActivity
echo.
echo Done. App should be open on your phone.

