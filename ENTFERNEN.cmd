@echo off
title Radeon-atieclxx-SSD-Fix - Entfernen
if not exist "%~dp0Skript\entfernen.ps1" (
  echo Bitte die ZIP-Datei zuerst vollstaendig entpacken und dann ENTFERNEN.cmd starten.
  pause
  exit /b 1
)
fltmc >nul 2>&1 || (powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" & exit /b)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Skript\entfernen.ps1"
echo.
pause
