@echo off
REM Build, install, and launch donish_app on connected Android device.
REM Use this instead of "flutter run" to avoid the manifest-read error.
set FLUTTER=C:\Users\SARDOR\Downloads\flutter_windows_3.41.4-stable\flutter\bin\flutter.bat
set ADB=C:\Users\SARDOR\AppData\Local\Android\Sdk\platform-tools\adb.exe
set APK=%~dp0build\app\outputs\flutter-apk\app-debug.apk

cd /d "%~dp0"
echo Building debug APK...
call "%FLUTTER%" build apk --debug
if errorlevel 1 exit /b 1

echo.
echo Installing on device...
"%ADB%" install -r "%APK%"
if errorlevel 1 exit /b 1

echo.
echo Launching app...
"%ADB%" shell am start -n com.example.donish_app/com.example.donish_app.MainActivity
echo.
echo Done. App should be open on your phone.
