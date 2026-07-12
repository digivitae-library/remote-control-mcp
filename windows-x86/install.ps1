# Remote Control MCP - Installation Script for Windows
# Installs RCM (remote-control-mcp) with all platform directories

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "         Remote Control MCP - RCM Installation Wizard         " -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""
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

function Find-BinRoot {
    param([string]$ScriptDir)
    $knownPlatforms = @("windows-x86","windows-x64","windows-arm64","linux-x86","linux-x64","linux-arm64","macos-x64","macos-arm64")
    foreach ($p in $knownPlatforms) {
        if (Test-Path "$ScriptDir\$p\worker") { return $ScriptDir }
    }
    $parent = Split-Path -Parent $ScriptDir
    foreach ($p in $knownPlatforms) {
        if (Test-Path "$parent\$p\worker") { return $parent }
    }
    return $ScriptDir
}

# ─── Main Installation Flow ─────────────────────────────────────────

Write-Banner

$platform = Get-Platform
Write-Host "  Detected platform: " -NoNewline
Write-Host "$platform" -ForegroundColor Green
Write-Host "  OS: Windows $([System.Environment]::OSVersion.Version)"
Write-Host "  Architecture: $env:PROCESSOR_ARCHITECTURE"
Write-Host ""

# Determine bin root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinRoot = Find-BinRoot -ScriptDir $ScriptDir
Write-Host "  Source directory: $BinRoot"
Write-Host ""

# Step 1: Installation directory
Write-Host "  [1/4] Installation Directory" -ForegroundColor Blue
$defaultPath = $ScriptDir
$InstallPath = Read-WithDefault -Prompt "Install path" -Default $defaultPath
Write-Host "  -> $InstallPath" -ForegroundColor Gray
Write-Host ""

# Step 2: Copy all platform directories (if different from source)
Write-Host "  [2/4] Copying platform directories" -ForegroundColor Blue
if ($InstallPath -ne $BinRoot) {
    $knownPlatforms = @("windows-x86","windows-x64","windows-arm64","linux-x86","linux-x64","linux-arm64","macos-x64","macos-arm64")
    foreach ($p in $knownPlatforms) {
        $srcPlatform = "$BinRoot\$p"
        if (Test-Path $srcPlatform) {
            $dstPlatform = "$InstallPath\$p"
            if (Test-Path $dstPlatform) { Remove-Item -Recurse -Force $dstPlatform }
            Copy-Item -Recurse $srcPlatform $dstPlatform
            Write-Host "    $p -> copied"
        }
    }
} else {
    Write-Host "    Install path is same as source, skipping copy."
}
Write-Host ""

# Step 3: Copy current platform's rcm/ to install root
Write-Host "  [3/4] Setting up RCM for $platform" -ForegroundColor Blue
$rcmSrc = "$InstallPath\$platform\rcm"
if (-not (Test-Path $rcmSrc)) {
    $rcmSrc = "$BinRoot\$platform\rcm"
}
if (Test-Path $rcmSrc) {
    $rcmDst = "$InstallPath\rcm"
    if (Test-Path $rcmDst) { Remove-Item -Recurse -Force $rcmDst }
    Copy-Item -Recurse $rcmSrc $rcmDst
    Write-Host "    RCM copied to $rcmDst"
} else {
    Write-Host "    Warning: RCM not found for platform $platform" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Create start.cmd
Write-Host "  [4/4] Creating start script" -ForegroundColor Blue
$startScript = @"
@echo off
cd /d "%~dp0"
rcm\remote-control-mcp.exe
"@
Set-Content -Path "$InstallPath\start.cmd" -Value $startScript -Encoding ASCII
Write-Host "    Created: $InstallPath\start.cmd"
Write-Host ""

# Done
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "          Installation Complete!                              " -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Install location:  " -NoNewline; Write-Host "$InstallPath" -ForegroundColor Cyan
Write-Host "  RCM directory:     " -NoNewline; Write-Host "$InstallPath\rcm" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start RCM:  " -NoNewline; Write-Host "$InstallPath\start.cmd" -ForegroundColor Green
Write-Host "  To stop:    Ctrl+C or close terminal"
Write-Host ""
Write-Host "  After starting RCM, use menu [6] to generate distributable Worker packages."
Write-Host ""
