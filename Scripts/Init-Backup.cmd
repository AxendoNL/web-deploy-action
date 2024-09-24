@echo off
setlocal

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrative privileges...
    powershell.exe -Command "Start-Process cmd -ArgumentList '/c', '%~f0', '%*' -Verb RunAs"
    exit /b
)

:: Check if the right number of arguments are passed
if "%~1"=="" (
    echo Usage: %0 scriptPath websiteName skipPaths
    exit /b 1
)

set scriptPath=%~1
set websiteName=%~2
set skipPaths=%~3

:: Run the PowerShell script with the provided parameters
powershell.exe -ExecutionPolicy Bypass -File %scriptPath% -websiteName %websiteName% -skipPaths %skipPaths%

endlocal
