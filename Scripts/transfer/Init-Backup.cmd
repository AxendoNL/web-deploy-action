@echo off
setlocal

:: Check if the script is running with administrative privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrative privileges...
    powershell.exe -Command "Start-Process cmd -ArgumentList '/c, %~0 %*' -Verb RunAs"
    exit /b
)

:: Use placeholders for variables
set scriptPath={{SCRIPT_PATH_PLACEHOLDER}}
set websiteName={{WEBSITE_NAME_PLACEHOLDER}}
set skipPaths={{SKIP_PATHS_PLACEHOLDER}}

:: Replace these placeholders dynamically in your GitHub Actions workflow

powershell.exe -ExecutionPolicy Bypass -File %scriptPath% -websiteName %websiteName% -skipPaths %skipPaths%

endlocal
