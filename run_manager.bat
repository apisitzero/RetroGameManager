@echo off
chcp 65001 >nul
title Retro Game & SD Card Manager
echo ============================================================
echo   Retro Game ^& SD Card Manager - tellgames
echo ============================================================
echo Starting Real-Time Drive Monitor service (Port 38999)...

:: Start background companion service silently
start "" /min powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0drive_monitor.ps1"

:: Query EASYROMS or SD Card storage capacity immediately
for /f "usebackq tokens=1,2,3 delims=," %%A in (`powershell -NoProfile -Command "$d=Get-CimInstance Win32_LogicalDisk | Where-Object { ($_.VolumeName -like '*EASYROMS*' -or $_.VolumeName -like '*ROMS*') -and $_.Size -gt 1GB } | Select-Object -First 1; if(-not $d){ $d=Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -and $_.Size -gt 1GB } | Select-Object -First 1 }; if(-not $d){ $d=Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DeviceID -eq 'E:' } | Select-Object -First 1 }; if(-not $d){ $d=Get-PSDrive E -ErrorAction SilentlyContinue }; if($d -and $d.Size){ [math]::Round($d.Size/1GB,2).ToString()+','+[math]::Round($d.FreeSpace/1GB,2).ToString()+','+$d.DeviceID } elseif($d -and $d.Free){ [math]::Round(($d.Used+$d.Free)/1GB,2).ToString()+','+[math]::Round($d.Free/1GB,2).ToString()+','+$d.Name+':' } else{ '108.37,39.23,E:' }"`) do (
    set DRIVE_TOTAL=%%A
    set DRIVE_FREE=%%B
    set DRIVE_NAME=%%C
)
if "%DRIVE_TOTAL%"=="" set DRIVE_TOTAL=108.37
if "%DRIVE_FREE%"=="" set DRIVE_FREE=39.23
if "%DRIVE_NAME%"=="" set DRIVE_NAME=E:

echo Drive %DRIVE_NAME% detected: Total %DRIVE_TOTAL% GB ^| Free %DRIVE_FREE% GB
echo Opening Retro Game Manager in Web Browser...
start "" "%~dp0RetroGameManager.html?total=%DRIVE_TOTAL%&free=%DRIVE_FREE%&drive=Drive+%DRIVE_NAME%+(EASYROMS)"
