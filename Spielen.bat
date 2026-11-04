@echo off
setlocal
chcp 65001 >nul
title Chibi Legends starten

rem ---- Pfade (bei Bedarf anpassen) ----
set "PROJEKT=C:\Users\denni\Projects\Chibi-Legends"
set "GODOT_DIR=C:\Users\denni\Downloads\Godot_v4.7.2-stable_win64.exe"
set "GODOT=%GODOT_DIR%\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%GODOT_DIR%\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%PROJEKT%\project.godot" (
  echo Projekt nicht gefunden: %PROJEKT%
  echo Bitte oben in dieser Datei PROJEKT anpassen.
  pause & exit /b 1
)
if not exist "%GODOT%" (
  echo Godot nicht gefunden in: %GODOT_DIR%
  echo Bitte oben in dieser Datei GODOT_DIR anpassen.
  pause & exit /b 1
)

cd /d "%PROJEKT%"

echo [1/3] Neuesten Stand holen ...
git fetch origin main
if errorlevel 1 (
  echo Kein Update moeglich (kein Internet oder kein git^). Starte mit dem lokalen Stand.
) else (
  git checkout main
  if errorlevel 1 (
    echo Lokale Aenderungen blockieren den Wechsel auf main. Sie werden beiseitegelegt ^(git stash^).
    git stash push -u -m "Spielen.bat %date% %time%"
    git checkout main
  )
  git pull --ff-only origin main
)

echo [2/3] Assets importieren (beim ersten Mal dauert das etwas) ...
"%GODOT%" --headless --path "%PROJEKT%" --import >nul 2>&1

echo [3/3] Spiel startet ...
start "" "%GODOT%" --path "%PROJEKT%"
endlocal
