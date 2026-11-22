@echo off
setlocal
cd /d "%~dp0"
title Black Box - Local Prototype

if not exist "pubspec.yaml" (
  echo Open this launcher from the fully extracted project folder.
  pause
  exit /b 1
)

if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "PATH=%LOCALAPPDATA%\Programs\Git\cmd;%PATH%"
if exist "%USERPROFILE%\Desktop\flutter\bin\flutter.bat" set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"

"%SystemRoot%\System32\where.exe" git >nul 2>nul
if errorlevel 1 (
  echo Git was not found. Send this message to ChatGPT with your Git installation folder.
  pause
  exit /b 1
)
"%SystemRoot%\System32\where.exe" flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Send this message to ChatGPT with your Flutter installation folder.
  pause
  exit /b 1
)

echo Black Box - version 0.5.0+8
echo Getting the required Flutter packages. Internet access is needed.
call flutter pub get
if errorlevel 1 (
  echo Package setup failed. Copy the error above and send it to ChatGPT.
  pause
  exit /b 1
)

echo.
echo Starting the app. The first compile may take a few minutes.
echo When Flutter says the app is being served, open this address in your normal Chrome window:
echo http://127.0.0.1:54321
echo.
echo Field Terminal starts in Dark mode. Use the top-right sun/moon button for Light.
echo Map shows your local plan locations. Its map imagery needs internet.
echo Kit - My pack is your personal list. Open guides to import PDFs and videos.
echo Guide files stay in this browser. Keep their originals as a backup.
echo Keep this window open while you use the app. Press q here to stop it.
echo Use the same browser profile and this exact address to keep your saved plan between runs.
echo.
call flutter run -d web-server --web-hostname=127.0.0.1 --web-port=54321
if errorlevel 1 (
  echo The preview stopped with an error. Copy the error above and send it to ChatGPT.
  echo If port 54321 is already in use, close the other Black Box launcher window and try again.
  pause
  exit /b 1
)
endlocal
