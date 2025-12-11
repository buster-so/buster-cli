# Buster CLI Installation Script for Windows
# Usage: irm https://platform.buster.so/cli | iex
# Or with version: powershell -Command "& { $env:BUSTER_VERSION='v0.4.2'; irm https://platform.buster.so/cli | iex }"

param(
    [string]$Version = "",
    [switch]$Beta,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

$REPO = "buster-so/buster-cli"
$BINARY_NAME = "buster.exe"
$ARCHIVE = "buster-cli-windows-x86_64.zip"

# Check for environment variable override
if ($env:BUSTER_VERSION) {
    $Version = $env:BUSTER_VERSION
}

# Show help
if ($Help) {
    Write-Host "Buster CLI Installation Script for Windows"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  irm https://platform.buster.so/cli | iex                    # Install latest stable"
    Write-Host "  .\install.ps1 -Version v0.4.2                               # Install specific version"
    Write-Host "  .\install.ps1 -Beta                                         # Install latest beta"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  BUSTER_VERSION       Set version to install (e.g., v0.4.2)"
    Write-Host "  BUSTER_INSTALL_DIR   Set custom install directory"
    Write-Host ""
    exit 0
}

function Get-LatestVersion {
    param([bool]$IncludePrerelease = $false)
    
    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases?per_page=100"
        
        if ($IncludePrerelease) {
            $release = $releases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        } else {
            $release = $releases | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1
        }
        
        if ($release) {
            return $release.tag_name
        }
        return $null
    } catch {
        return $null
    }
}

# Determine version to install
if ($Beta) {
    Write-Host "Fetching latest beta version..." -ForegroundColor Cyan
    $Version = Get-LatestVersion -IncludePrerelease $true
    if (-not $Version) {
        Write-Host "Error: Failed to fetch latest beta version" -ForegroundColor Red
        exit 1
    }
    Write-Host "Latest beta version: $Version" -ForegroundColor Cyan
}

if (-not $Version -or $Version -eq "latest") {
    Write-Host "Fetching latest stable version..." -ForegroundColor Cyan
    $Version = Get-LatestVersion -IncludePrerelease $false
    if (-not $Version) {
        Write-Host "Error: Failed to fetch latest version" -ForegroundColor Red
        exit 1
    }
    Write-Host "Latest version: $Version" -ForegroundColor Cyan
}

# Normalize version (ensure 'v' prefix)
if (-not $Version.StartsWith("v")) {
    $Version = "v$Version"
}

# Determine installation directory
$INSTALL_DIR = if ($env:BUSTER_INSTALL_DIR) { $env:BUSTER_INSTALL_DIR } else { "$env:LOCALAPPDATA\Programs\Buster" }

Write-Host ""
Write-Host "Installing Buster CLI $Version for Windows..." -ForegroundColor Green
Write-Host ""

# Create installation directory if it doesn't exist
if (-not (Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
}

# Create temporary directory
$TMP_DIR = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }

try {
    # Download release
    $DOWNLOAD_URL = "https://github.com/$REPO/releases/download/$Version/$ARCHIVE"
    Write-Host "[INFO] Downloading from $DOWNLOAD_URL..." -ForegroundColor Cyan
    $ARCHIVE_PATH = Join-Path $TMP_DIR $ARCHIVE
    
    try {
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ARCHIVE_PATH
    } catch {
        Write-Host "[ERROR] Failed to download. Version $Version may not exist." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[SUCCESS] Downloaded successfully" -ForegroundColor Green

    # Extract archive
    Write-Host "[INFO] Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $ARCHIVE_PATH -DestinationPath $TMP_DIR -Force

    # Install binary
    Write-Host "[INFO] Installing to $INSTALL_DIR..." -ForegroundColor Cyan
    $SOURCE = Join-Path $TMP_DIR $BINARY_NAME
    
    # Check for both 'buster.exe' and 'buster-cli.exe' for compatibility
    if (-not (Test-Path $SOURCE)) {
        $SOURCE = Join-Path $TMP_DIR "buster-cli.exe"
    }
    
    if (-not (Test-Path $SOURCE)) {
        Write-Host "[ERROR] Binary not found in archive" -ForegroundColor Red
        exit 1
    }
    
    $DEST = Join-Path $INSTALL_DIR "buster.exe"
    Copy-Item -Path $SOURCE -Destination $DEST -Force
    Write-Host "[SUCCESS] Binary installed" -ForegroundColor Green

    # Install node_modules if present (contains DuckDB native bindings)
    $NODE_MODULES_SOURCE = Join-Path $TMP_DIR "node_modules"
    if (Test-Path $NODE_MODULES_SOURCE) {
        Write-Host "[INFO] Installing DuckDB native bindings..." -ForegroundColor Cyan
        $NODE_MODULES_DEST = Join-Path $INSTALL_DIR "node_modules"
        if (Test-Path $NODE_MODULES_DEST) {
            Remove-Item -Path $NODE_MODULES_DEST -Recurse -Force
        }
        Copy-Item -Path $NODE_MODULES_SOURCE -Destination $NODE_MODULES_DEST -Recurse -Force
        Write-Host "[SUCCESS] DuckDB native bindings installed" -ForegroundColor Green
    }

    # Add to PATH if not already there
    $USER_PATH = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($USER_PATH -notlike "*$INSTALL_DIR*") {
        Write-Host "[INFO] Adding $INSTALL_DIR to PATH..." -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("Path", "$USER_PATH;$INSTALL_DIR", "User")
        $env:Path = "$env:Path;$INSTALL_DIR"
        Write-Host "[SUCCESS] Added to PATH" -ForegroundColor Green
    } else {
        Write-Host "[SUCCESS] Already in PATH" -ForegroundColor Green
    }

    # Verify installation
    Write-Host "[INFO] Verifying installation..." -ForegroundColor Cyan
    try {
        $versionOutput = & $DEST --version 2>&1
        Write-Host "[SUCCESS] Installation verified! $versionOutput" -ForegroundColor Green
    } catch {
        Write-Host "[SUCCESS] Binary installed successfully" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " Installation complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run 'buster --help' to get started." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Note: You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
    Write-Host ""
}
finally {
    # Cleanup
    if (Test-Path $TMP_DIR) {
        Remove-Item -Path $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}
