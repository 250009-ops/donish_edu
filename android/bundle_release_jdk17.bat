@echo off
setlocal EnableDelayedExpansion
set "JAVA_HOME=C:\Users\SARDOR\.java\jdk-17.0.17+10"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d "%~dp0"

set "LOG=%~dp0..\gradle_bundle_jdk17.log"
echo JAVA_HOME=%JAVA_HOME%> "%LOG%"
"%JAVA_HOME%\bin\java.exe" -version>> "%LOG%" 2>&1

"%JAVA_HOME%\bin\java.exe" -classpath "%~dp0gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain :app:bundleRelease --no-daemon --stacktrace>> "%LOG%" 2>&1

echo gradle_exit=!ERRORLEVEL!>> "%LOG%"
exit /b !ERRORLEVEL!
