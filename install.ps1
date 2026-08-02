# Remote Control MCP - Installation Script for Windows
# Installs RCM (remote-control-mcp) with all platform directories

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$KnownPlatforms = @(
    "windows-x86", "windows-x64", "windows-arm64",
    "linux-x86", "linux-x64", "linux-arm64",
    "macos-x64", "macos-arm64", "macos-universal"
)

$script:Warnings = 0

function Write-Warn {
    param([string]$Message)
    Write-Host "    Warning: $Message" -ForegroundColor Yellow
    $script:Warnings++
}

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
    return $result.Trim().Trim('"')
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

# Locate the directory that holds the per-platform directories. Supports being
# run from bin/ itself, from a platform directory, or from a source checkout root
# where the platform directories live under bin\.
function Find-BinRoot {
    param([string]$ScriptDir)
    $parent = Split-Path -Parent $ScriptDir
    $candidates = @($ScriptDir, (Join-Path $ScriptDir "bin"))
    if ($parent) {
        $candidates += @($parent, (Join-Path $parent "bin"))
    }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) { continue }
        foreach ($p in $KnownPlatforms) {
            if ((Test-Path (Join-Path $candidate "$p\worker")) -or
                (Test-Path (Join-Path $candidate "$p\rcm"))) {
                return (Resolve-Path $candidate).Path
            }
        }
    }
    return $ScriptDir
}

# --- Main Installation Flow -----------------------------------------

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

$foundAny = $false
foreach ($p in $KnownPlatforms) {
    if (Test-Path (Join-Path $BinRoot $p)) { $foundAny = $true; break }
}
if (-not $foundAny) {
    Write-Host "  ERROR: No platform directories found under $BinRoot" -ForegroundColor Red
    Write-Host "  Run this script from the bin\ directory of a release package."
    exit 1
}

# Step 1: Installation directory
Write-Host "  [1/4] Installation Directory" -ForegroundColor Blue
$InstallPath = Read-WithDefault -Prompt "Install path" -Default $ScriptDir
try {
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    $InstallPath = (Resolve-Path $InstallPath).Path
} catch {
    Write-Host "  ERROR: Cannot create install directory: $InstallPath" -ForegroundColor Red
    exit 1
}
Write-Host "  -> $InstallPath" -ForegroundColor Gray
Write-Host ""

# Step 2: Copy all platform directories (if different from source)
Write-Host "  [2/4] Copying platform directories" -ForegroundColor Blue
if ($InstallPath -ne $BinRoot) {
    $copied = 0
    foreach ($p in $KnownPlatforms) {
        $srcPlatform = Join-Path $BinRoot $p
        if (-not (Test-Path $srcPlatform)) { continue }
        $dstPlatform = Join-Path $InstallPath $p
        try {
            if (Test-Path $dstPlatform) { Remove-Item -Recurse -Force $dstPlatform }
            Copy-Item -Recurse $srcPlatform $dstPlatform
            Write-Host "    $p -> copied"
            $copied++
        } catch {
            Write-Warn "failed to copy $p ($($_.Exception.Message))"
        }
    }
    if ($copied -eq 0) { Write-Warn "no platform directory was copied" }
    $readme = Join-Path $BinRoot "README.md"
    if (Test-Path $readme) {
        Copy-Item -Force $readme (Join-Path $InstallPath "README.md")
    }
    $installScript = Join-Path $BinRoot "install.ps1"
    if ((Test-Path $installScript) -and ($installScript -ne (Join-Path $InstallPath "install.ps1"))) {
        Copy-Item -Force $installScript (Join-Path $InstallPath "install.ps1")
    }
} else {
    Write-Host "    Install path is same as source, skipping copy."
}
Write-Host ""

# Step 3: Copy current platform's rcm/ to install root
Write-Host "  [3/4] Setting up RCM for $platform" -ForegroundColor Blue
$rcmSrc = $null
foreach ($base in @($InstallPath, $BinRoot)) {
    $candidate = Join-Path $base "$platform\rcm"
    if (Test-Path $candidate) { $rcmSrc = $candidate; break }
}
if ($rcmSrc) {
    try {
        $rcmDst = Join-Path $InstallPath "rcm"
        if (Test-Path $rcmDst) { Remove-Item -Recurse -Force $rcmDst }
        Copy-Item -Recurse $rcmSrc $rcmDst
        Write-Host "    RCM copied to $rcmDst"
    } catch {
        Write-Warn "failed to copy RCM from $rcmSrc ($($_.Exception.Message))"
    }
} else {
    Write-Warn "RCM not found for platform $platform"
}
Write-Host ""

# Step 4: Create start.cmd
Write-Host "  [4/4] Creating start script" -ForegroundColor Blue
$startScript = @"
@echo off
cd /d "%~dp0"
if not exist "rcm\remote-control-mcp.exe" (
    echo ERROR: rcm\remote-control-mcp.exe not found.
    exit /b 1
)
rcm\remote-control-mcp.exe %*
"@
Set-Content -Path (Join-Path $InstallPath "start.cmd") -Value $startScript -Encoding ASCII
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
Write-Host "  After starting RCM, use the 'Generate distributable Worker packages' menu entry."
if ($script:Warnings -gt 0) {
    Write-Host ""
    Write-Host "  $($script:Warnings) warning(s) reported above." -ForegroundColor Yellow
}
Write-Host ""
