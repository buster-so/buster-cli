# Buster CLI Installation Script for Windows
# Usage: irm https://platform.buster.so/cli | iex

$ErrorActionPreference = 'Stop'

$REPO = "buster-so/buster-cli"
$BINARY_NAME = "buster.exe"
$ARCHIVE = "buster-cli-windows-x86_64.zip"

# Determine installation directory
$INSTALL_DIR = if ($env:BUSTER_INSTALL_DIR) { $env:BUSTER_INSTALL_DIR } else { "$env:LOCALAPPDATA\Programs\Buster" }

Write-Host "Installing Buster CLI for Windows..." -ForegroundColor Green

# Create installation directory if it doesn't exist
if (-not (Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
}

# Create temporary directory
$TMP_DIR = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }

try {
    # Download latest release
    $DOWNLOAD_URL = "https://github.com/$REPO/releases/latest/download/$ARCHIVE"
    Write-Host "Downloading from $DOWNLOAD_URL..."
    $ARCHIVE_PATH = Join-Path $TMP_DIR $ARCHIVE
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ARCHIVE_PATH

    # Extract archive
    Write-Host "Extracting..."
    Expand-Archive -Path $ARCHIVE_PATH -DestinationPath $TMP_DIR -Force

    # Install binary
    Write-Host "Installing to $INSTALL_DIR..."
    $SOURCE = Join-Path $TMP_DIR $BINARY_NAME
    $DEST = Join-Path $INSTALL_DIR $BINARY_NAME
    Copy-Item -Path $SOURCE -Destination $DEST -Force

    # Add to PATH if not already there
    $USER_PATH = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($USER_PATH -notlike "*$INSTALL_DIR*") {
        Write-Host "Adding $INSTALL_DIR to PATH..."
        [Environment]::SetEnvironmentVariable("Path", "$USER_PATH;$INSTALL_DIR", "User")
        $env:Path = "$env:Path;$INSTALL_DIR"
    }

    Write-Host "`n✅ Buster CLI installed successfully!" -ForegroundColor Green
    Write-Host "`nRun 'buster --help' to get started." -ForegroundColor Cyan
    Write-Host "Note: You may need to restart your terminal for PATH changes to take effect.`n" -ForegroundColor Yellow
}
finally {
    # Cleanup
    Remove-Item -Path $TMP_DIR -Recurse -Force
}
