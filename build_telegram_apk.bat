@echo off
setlocal

set "ROOT=%~dp0"
set "FLUTTER=%USERPROFILE%\flutter_sdk\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\Users\SARDOR\flutter_sdk\bin\flutter.bat"
set "LOG=%ROOT%_telegram_apk_build.log"

echo Build started %DATE% %TIME% > "%LOG%"
echo ROOT=%ROOT%>> "%LOG%"
echo FLUTTER=%FLUTTER%>> "%LOG%"

if not exist "%FLUTTER%" (
  echo ERROR: Flutter not found at %FLUTTER%>> "%LOG%"
  echo Flutter not found. Update FLUTTER path in build_telegram_apk.bat
  exit /b 1
)

cd /d "%ROOT%"
call "%FLUTTER%" pub get >> "%LOG%" 2>&1
if errorlevel 1 (
  echo ERROR: flutter pub get failed>> "%LOG%"
  exit /b 1
)

REM Build a reliable distribution APK for modern Android phones (arm64).
REM In this project environment, generic release APK can be invalid/small and crash on launch.
call "%FLUTTER%" build apk --release --target-platform android-arm64 >> "%LOG%" 2>&1
if errorlevel 1 (
  echo ERROR: flutter build apk failed>> "%LOG%"
  exit /b 1
)

if exist "%ROOT%build\app\outputs\flutter-apk\app-release.apk" (
  echo SUCCESS: %ROOT%build\app\outputs\flutter-apk\app-release.apk>> "%LOG%"
  echo.
  echo DONE: APK created
  echo %ROOT%build\app\outputs\flutter-apk\app-release.apk
) else (
  echo ERROR: APK output not found>> "%LOG%"
  exit /b 1
)

exit /b 0
