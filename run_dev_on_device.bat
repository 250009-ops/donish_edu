@echo off
REM Run Donish on a connected Android phone with hot reload (press r in this window).
REM API stays on production EC2 (https://api.donish.live) — only UI runs locally.
set "FLUTTER=%USERPROFILE%\flutter_sdk\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\Users\user\flutter_sdk\bin\flutter.bat"
if not exist "%FLUTTER%" (
  echo Flutter not found. Install Flutter or edit FLUTTER in this script.
  exit /b 1
)
if exist "%ProgramFiles%\Android\Android Studio\jbr" (
  set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
  set "PATH=%JAVA_HOME%\bin;%PATH%"
)
cd /d "%~dp0"
echo Starting debug session on connected device...
echo   Hot reload: r    Hot restart: R    Quit: q
echo.
call "%FLUTTER%" run -d R3CR90S296W
