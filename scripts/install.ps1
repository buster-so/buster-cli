# Buster CLI Installation Script for Windows PowerShell
# Usage: iwr -useb https://platform.buster.so/cli | iex

param(
    [string]$Version = "latest",
    [switch]$Beta,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Parse arguments for piped usage (iwr | iex -- --version v1.0.0)
if ($args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--version" {
                if ($i + 1 -lt $args.Count) {
                    $Version = $args[$i + 1]
                    $i++
                }
            }
            "--beta" {
                $Beta = $true
            }
            "--help" {
                $Help = $true
            }
            "-h" {
                $Help = $true
            }
        }
    }
}

# Configuration
$REPO = "buster-so/buster-cli"
$BINARY_NAME = "buster-cli"
$INSTALL_NAME = "buster"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-Architecture {
    $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    switch ($arch) {
        "AMD64" { return "x86_64" }
        "ARM64" { return "arm64" }
        default {
            Write-Error "Unsupported architecture: $arch"
            exit 1
        }
    }
}

function Get-LatestVersion {
    param(
        [bool]$IncludePrerelease = $false
    )
    
    try {
        if ($IncludePrerelease) {
            # Get latest release including prereleases
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest"
            return $response.tag_name
        }
        else {
            # Get latest stable release (first non-prerelease)
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases?per_page=100"
            $stableRelease = $releases | Where-Object { -not $_.prerelease } | Select-Object -First 1
            if ($stableRelease) {
                return $stableRelease.tag_name
            }
            # Fallback to latest if no stable release found
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest"
            return $response.tag_name
        }
    }
    catch {
        Write-Error "Failed to fetch latest version: $_"
        exit 1
    }
}

function Install-BusterCLI {
    $arch = Get-Architecture
    Write-Info "Detected architecture: $arch"
    
    # Get version if not specified
    if ($Version -eq "latest") {
        Write-Info "Fetching latest stable version..."
        $Version = Get-LatestVersion -IncludePrerelease $false
        Write-Info "Latest version: $Version"
    }
    
    # Normalize version format (remove 'v' prefix if present, add it back for tag)
    $versionTag = $Version
    if ($versionTag -notmatch '^v') {
        $versionTag = "v$versionTag"
    }
    
    # Construct download URL
    $filename = "$BINARY_NAME-windows-$arch.zip"
    $downloadUrl = "https://github.com/$REPO/releases/download/$versionTag/$filename"
    
    Write-Info "Downloading from: $downloadUrl"
    
    # Create temporary directory
    $tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
    $zipPath = Join-Path $tempDir $filename
    
    try {
        # Download the binary
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        Write-Success "Downloaded binary successfully"
        
        # Extract the archive
        Write-Info "Extracting archive..."
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Determine install directory
        $installDir = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        
        # Create install directory if it doesn't exist
        if (!(Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        }
        
        # Move binary to install directory
        # Note: The archive contains 'buster.exe' directly, not 'buster-cli.exe'
        $binaryPath = Join-Path $tempDir "$INSTALL_NAME.exe"
        $targetPath = Join-Path $installDir "$INSTALL_NAME.exe"
        
        if (!(Test-Path $binaryPath)) {
            # Fallback to old naming for backward compatibility
            $binaryPath = Join-Path $tempDir "$BINARY_NAME.exe"
            if (!(Test-Path $binaryPath)) {
                Write-Error "Binary not found after extraction. Looked for both $INSTALL_NAME.exe and $BINARY_NAME.exe"
                exit 1
            }
        }
        
        # Remove existing binary if it exists
        if (Test-Path $targetPath) {
            Remove-Item $targetPath -Force
        }
        
        Move-Item $binaryPath $targetPath
        
        # Copy node_modules directory if it exists (contains DuckDB native bindings)
        $nodeModulesPath = Join-Path $tempDir "node_modules"
        $targetNodeModulesPath = Join-Path $installDir "node_modules"
        
        if (Test-Path $nodeModulesPath) {
            Write-Info "Installing DuckDB native bindings..."
            
            # Remove existing node_modules if it exists
            if (Test-Path $targetNodeModulesPath) {
                Remove-Item $targetNodeModulesPath -Recurse -Force
            }
            
            try {
                Copy-Item $nodeModulesPath $targetNodeModulesPath -Recurse -Force
                Write-Success "DuckDB native bindings installed"
            }
            catch {
                Write-Warning "Failed to copy DuckDB bindings. DuckDB features may not work: $_"
            }
        }
        else {
            Write-Warning "node_modules directory not found in archive. DuckDB features may not work."
        }
        
        Write-Success "Installed $INSTALL_NAME to $targetPath"
        
        # Verify installation
        Write-Info "Verifying installation..."
        Start-Sleep -Seconds 1
        
        try {
            $versionOutput = & $INSTALL_NAME --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Installation verified! $versionOutput"
            } else {
                Write-Success "Installation successful! Binary is available as '$INSTALL_NAME'"
            }
        }
        catch {
            Write-Warning "Binary installed but verification failed. You may need to restart your terminal."
        }
        
        Write-Success "🎉 Installation complete!"
        Write-Info "You can now use the '$INSTALL_NAME' command to interact with the Buster CLI"
        Write-Info "Try running: $INSTALL_NAME --help"
        
    }
    finally {
        # Clean up temporary directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}

function Show-Help {
    Write-Host @"
Buster CLI Installation Script for Windows PowerShell

Usage: 
    .\install.ps1 [-Version <version>] [-Beta]
    iwr -useb https://platform.buster.so/cli | iex -- --version <version> --beta

Parameters:
    -Version     Install specific version (default: latest stable)
                 Examples: v4.1.0, v4.1.0-beta, 4.1.0-beta
    -Beta        Install latest beta/prerelease version
    -Help        Show this help message

Examples:
    .\install.ps1                      # Install latest stable version
    .\install.ps1 -Version v4.1.0      # Install specific stable version
    .\install.ps1 -Version v4.1.0-beta # Install specific beta version
    .\install.ps1 -Version 4.1.0-beta  # Install specific beta version (without 'v')
    .\install.ps1 -Beta                # Install latest beta version

"@
}

# Handle help flag
if ($Help) {
    Show-Help
    exit 0
}

# Handle beta flag
if ($Beta -and $Version -eq "latest") {
    Write-Info "Fetching latest beta version..."
    $Version = Get-LatestVersion -IncludePrerelease $true
    Write-Info "Latest beta version: $Version"
}

Write-Host ""
Write-Info "🚀 Buster CLI Installation Script for Windows"
Write-Info "This script will download and install the latest Buster CLI binary"
Write-Host ""

try {
    Install-BusterCLI
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}
