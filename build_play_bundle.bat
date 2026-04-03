@echo off
setlocal
set "ROOT=%~dp0"
set "FLUTTER=%USERPROFILE%\flutter_sdk\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\Users\SARDOR\flutter_sdk\bin\flutter.bat"
set "LOG=%ROOT%_play_bundle_build.log"

echo Build started %DATE% %TIME% > "%LOG%"
echo ROOT=%ROOT%>> "%LOG%"

if not exist "%FLUTTER%" (
  echo ERROR: Flutter not found at %FLUTTER%>> "%LOG%"
  exit /b 1
)

cd /d "%ROOT%"
call "%FLUTTER%" pub get >> "%LOG%" 2>&1
echo pub get exit=%ERRORLEVEL%>> "%LOG%"
if errorlevel 1 exit /b 1

call "%FLUTTER%" build appbundle >> "%LOG%" 2>&1
echo build appbundle exit=%ERRORLEVEL%>> "%LOG%"
if errorlevel 1 exit /b 1

if exist "%ROOT%build\app\outputs\bundle\release\app-release.aab" (
  echo SUCCESS: app-release.aab>> "%LOG%"
  dir "%ROOT%build\app\outputs\bundle\release\app-release.aab">> "%LOG%"
) else (
  echo ERROR: app-release.aab missing>> "%LOG%"
  exit /b 1
)
exit /b 0
