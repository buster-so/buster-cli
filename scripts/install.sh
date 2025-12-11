#!/bin/bash
set -e

# Buster CLI Installation Script
# Usage: curl -fsSL https://platform.buster.so/cli | bash

REPO="buster-so/buster-cli"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="buster"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)
        case "$ARCH" in
            x86_64)
                PLATFORM="linux-x86_64"
                ARCHIVE="buster-cli-linux-x86_64.tar.gz"
                ;;
            *)
                echo "Error: Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        ;;
    Darwin*)
        case "$ARCH" in
            x86_64)
                PLATFORM="darwin-x86_64"
                ARCHIVE="buster-cli-darwin-x86_64.tar.gz"
                ;;
            arm64)
                PLATFORM="darwin-arm64"
                ARCHIVE="buster-cli-darwin-arm64.tar.gz"
                ;;
            *)
                echo "Error: Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Error: Unsupported operating system: $OS"
        exit 1
        ;;
esac

echo "Installing Buster CLI for $PLATFORM..."

# Create temporary directory
TMP_DIR="$(mktemp -d)"
trap "rm -rf $TMP_DIR" EXIT

# Download latest release
DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$ARCHIVE"
echo "Downloading from $DOWNLOAD_URL..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$ARCHIVE"

# Extract archive
echo "Extracting..."
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR"

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Install binary and node_modules (for DuckDB native bindings)
echo "Installing to $INSTALL_DIR..."
if [ -w "$INSTALL_DIR" ]; then
    mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    # Copy node_modules if present (contains DuckDB native bindings)
    if [ -d "$TMP_DIR/node_modules" ]; then
        rm -rf "$INSTALL_DIR/node_modules"
        mv "$TMP_DIR/node_modules" "$INSTALL_DIR/node_modules"
    fi
else
    echo "Installing to $INSTALL_DIR requires sudo..."
    sudo mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
    sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    # Copy node_modules if present (contains DuckDB native bindings)
    if [ -d "$TMP_DIR/node_modules" ]; then
        sudo rm -rf "$INSTALL_DIR/node_modules"
        sudo mv "$TMP_DIR/node_modules" "$INSTALL_DIR/node_modules"
    fi
fi

echo "✅ Buster CLI installed successfully!"
echo ""
echo "Run 'buster --help' to get started."
