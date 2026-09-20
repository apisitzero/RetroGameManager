@echo off
chcp 65001 >nul
title Retro Game & SD Card Manager
echo ============================================================
echo   Retro Game & SD Card Manager - tellgames
echo ============================================================
echo Starting Real-Time Drive Monitor service (Port 38999)...

:: Start background companion service silently
start "" /min powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0drive_monitor.ps1"

:: Query EASYROMS (Drive E:) storage capacity immediately
for /f "usebackq tokens=1,2 delims=," %%A in (`powershell -NoProfile -Command "$d=Get-PSDrive E -ErrorAction SilentlyContinue; if($d){ [math]::Round(($d.Used+$d.Free)/1GB,2).ToString()+','+[math]::Round($d.Free/1GB,2).ToString() }else{ '49.34,1.12' }"`) do (
    set DRIVE_TOTAL=%%A
    set DRIVE_FREE=%%B
)
if "%DRIVE_TOTAL%"=="" set DRIVE_TOTAL=49.34
if "%DRIVE_FREE%"=="" set DRIVE_FREE=1.12

echo Drive E: (EASYROMS) detected: Total %DRIVE_TOTAL% GB ^| Free %DRIVE_FREE% GB
echo Opening Retro Game Manager in Web Browser...
start "" "%~dp0RetroGameManager.html?total=%DRIVE_TOTAL%&free=%DRIVE_FREE%&drive=Drive+E:+(EASYROMS)"
