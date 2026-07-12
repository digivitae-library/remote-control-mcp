# Remote Control MCP - Installation Script for Windows
# Provides text-based UI to configure and generate startup scripts

param(
    [switch]$Silent,
    [string]$InstallPath = "",
    [int]$Port = 0
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         Remote Control MCP - Installation Wizard        ║" -ForegroundColor Cyan
    Write-Host "  ║                                                         ║" -ForegroundColor Cyan
    Write-Host "  ║   A dual-architecture MCP service for AI Agents         ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Current, [int]$Total, [string]$Title)
    Write-Host ""
    Write-Host "  [$Current/$Total] $Title" -ForegroundColor Blue
    Write-Host "  ────────────────────────────────────────────────────────────"
}

function Read-WithDefault {
    param([string]$Prompt, [string]$Default)
    Write-Host "  $Prompt " -NoNewline
    Write-Host "[$Default]" -NoNewline -ForegroundColor Yellow
    Write-Host ": " -NoNewline
    $result = Read-Host
    if ([string]::IsNullOrWhiteSpace($result)) { $result = $Default }
    return $result
}

function Get-Platform {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64"   { return "windows-x64" }
        "x86"     { return "windows-x86" }
        "ARM64"   { return "windows-arm64" }
        default   { return "windows-x64" }
    }
}

# ─── Main Installation Flow ─────────────────────────────────────────

Write-Banner

$platform = Get-Platform
Write-Host "  Detected platform: " -NoNewline
Write-Host "$platform" -ForegroundColor Green
Write-Host "  OS: Windows $([System.Environment]::OSVersion.Version)"
Write-Host "  Architecture: $env:PROCESSOR_ARCHITECTURE"

# Step 1: Installation directory
Write-Step -Current 1 -Total 5 -Title "Installation Directory"
if ([string]::IsNullOrWhiteSpace($InstallPath)) {
    $defaultPath = "C:\Program Files\RemoteControlMCP"
    $InstallPath = Read-WithDefault -Prompt "Install path" -Default $defaultPath
}
Write-Host "  -> $InstallPath" -ForegroundColor Gray

# Step 2: Service port
Write-Step -Current 2 -Total 5 -Title "Service Configuration"
if ($Port -eq 0) {
    $Port = [int](Read-WithDefault -Prompt "MCP service port" -Default "18888")
}
$WorkerName = Read-WithDefault -Prompt "Worker name" -Default "mcp-worker-1"

# Step 3: Supervisor settings
Write-Step -Current 3 -Total 5 -Title "Supervisor Settings"
$AutoRestart = Read-WithDefault -Prompt "Auto-restart on crash (true/false)" -Default "true"
$CheckInterval = Read-WithDefault -Prompt "Health check interval (seconds)" -Default "5"

# Step 4: Confirm
Write-Step -Current 4 -Total 5 -Title "Configuration Summary"
Write-Host "  Install Directory:  " -NoNewline; Write-Host "$InstallPath" -ForegroundColor Cyan
Write-Host "  Platform:           " -NoNewline; Write-Host "$platform" -ForegroundColor Cyan
Write-Host "  Service Port:       " -NoNewline; Write-Host "$Port" -ForegroundColor Cyan
Write-Host "  Worker Name:        " -NoNewline; Write-Host "$WorkerName" -ForegroundColor Cyan
Write-Host "  Auto Restart:       " -NoNewline; Write-Host "$AutoRestart" -ForegroundColor Cyan
Write-Host "  Check Interval:     " -NoNewline; Write-Host "${CheckInterval}s" -ForegroundColor Cyan
Write-Host ""

if (-not $Silent) {
    Write-Host "  Proceed with installation? " -NoNewline
    Write-Host "[Y/n]" -NoNewline -ForegroundColor Yellow
    Write-Host ": " -NoNewline
    $confirm = Read-Host
    if ($confirm -match "^[Nn]") {
        Write-Host "  Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Step 5: Install
Write-Step -Current 5 -Total 5 -Title "Installing"

# Create directories
Write-Host "  Creating directories..."
New-Item -ItemType Directory -Path "$InstallPath\config" -Force | Out-Null
New-Item -ItemType Directory -Path "$InstallPath\logs" -Force | Out-Null

# Copy binaries
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformDir = Join-Path $ScriptDir $platform

if (Test-Path "$PlatformDir\supervisor.exe") {
    Write-Host "  Copying binaries from $PlatformDir..."
    Copy-Item "$PlatformDir\supervisor.exe" "$InstallPath\supervisor.exe" -Force
    Copy-Item "$PlatformDir\worker.exe" "$InstallPath\worker.exe" -Force
} elseif (Test-Path "$ScriptDir\supervisor.exe") {
    Write-Host "  Copying binaries..."
    Copy-Item "$ScriptDir\supervisor.exe" "$InstallPath\supervisor.exe" -Force
    Copy-Item "$ScriptDir\worker.exe" "$InstallPath\worker.exe" -Force
} else {
    Write-Host "  Warning: Binaries not found. Please copy manually." -ForegroundColor Yellow
}

# Generate config
Write-Host "  Generating configuration file..."
$configContent = @"
[supervisor]
check_interval_secs = $CheckInterval

[[workers]]
name = "$WorkerName"
port = $Port
auto_restart = $AutoRestart
"@
Set-Content -Path "$InstallPath\config\default.toml" -Value $configContent -Encoding UTF8

# Generate start script
Write-Host "  Generating startup scripts..."
$startScript = @"
@echo off
REM Remote Control MCP - Startup Script
cd /d "%~dp0"

if "%1"=="" goto start
if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
if "%1"=="status" goto status
goto usage

:start
echo Starting Remote Control MCP...
echo   Config: %~dp0config\default.toml
echo   Port: $Port
start /B "" "%~dp0supervisor.exe" > logs\supervisor.log 2>&1
echo Started. Log: %~dp0logs\supervisor.log
goto end

:stop
echo Stopping Remote Control MCP...
taskkill /F /IM supervisor.exe >nul 2>&1
taskkill /F /IM worker.exe >nul 2>&1
echo Stopped.
goto end

:restart
call "%~f0" stop
timeout /t 2 /nobreak >nul
call "%~f0" start
goto end

:status
tasklist /FI "IMAGENAME eq supervisor.exe" 2>nul | find /i "supervisor.exe" >nul
if %ERRORLEVEL%==0 (
    echo Running.
) else (
    echo Not running.
)
goto end

:usage
echo Usage: %~nx0 [start^|stop^|restart^|status]
goto end

:end
"@
Set-Content -Path "$InstallPath\start.cmd" -Value $startScript -Encoding ASCII

# Generate PowerShell start script
$psStartScript = @"
# Remote Control MCP - PowerShell Startup Script
`$ErrorActionPreference = "Continue"
`$ServiceDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
Set-Location `$ServiceDir

switch (`$args[0]) {
    "start" {
        Write-Host "Starting Remote Control MCP..."
        Write-Host "  Config: `$ServiceDir\config\default.toml"
        Write-Host "  Port: $Port"
        Start-Process -FilePath "`$ServiceDir\supervisor.exe" ``
            -WindowStyle Hidden ``
            -RedirectStandardOutput "`$ServiceDir\logs\supervisor.log" ``
            -RedirectStandardError "`$ServiceDir\logs\supervisor-error.log"
        Write-Host "Started."
    }
    "stop" {
        Write-Host "Stopping Remote Control MCP..."
        Get-Process -Name "supervisor","worker" -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Host "Stopped."
    }
    "restart" {
        & `$MyInvocation.MyCommand.Path stop
        Start-Sleep -Seconds 2
        & `$MyInvocation.MyCommand.Path start
    }
    "status" {
        `$procs = Get-Process -Name "supervisor" -ErrorAction SilentlyContinue
        if (`$procs) {
            Write-Host "Running (PID: `$(`$procs.Id -join ', '))"
        } else {
            Write-Host "Not running."
        }
    }
    default {
        Write-Host "Usage: .\start.ps1 [start|stop|restart|status]"
    }
}
"@
Set-Content -Path "$InstallPath\start.ps1" -Value $psStartScript -Encoding UTF8

# Generate stop convenience script
Set-Content -Path "$InstallPath\stop.cmd" -Value "@echo off`r`ncall `"%~dp0start.cmd`" stop" -Encoding ASCII

# Done
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║          Installation Complete!                         ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Install location: " -NoNewline; Write-Host "$InstallPath" -ForegroundColor Cyan
Write-Host "  Configuration:    " -NoNewline; Write-Host "$InstallPath\config\default.toml" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start service:  " -NoNewline; Write-Host "$InstallPath\start.cmd start" -ForegroundColor Green
Write-Host "  Stop service:   " -NoNewline; Write-Host "$InstallPath\start.cmd stop" -ForegroundColor Green
Write-Host "  Check status:   " -NoNewline; Write-Host "$InstallPath\start.cmd status" -ForegroundColor Green
Write-Host "  View logs:      " -NoNewline; Write-Host "Get-Content $InstallPath\logs\supervisor.log -Wait" -ForegroundColor Green
Write-Host ""
