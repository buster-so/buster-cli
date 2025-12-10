#!/bin/bash
set -e

# Buster CLI Installation Script
# Usage: curl -fsSL https://platform.buster.so/cli | bash

REPO="buster-so/buster-cli"
BINARY_NAME="buster-cli"
INSTALL_NAME="buster"
VERSION="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS and architecture
detect_platform() {
    local os=""
    local arch=""
    local ext=""
    
    # Detect OS
    case "$(uname -s)" in
        Darwin*)
            os="darwin"
            ;;
        Linux*)
            os="linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            os="windows"
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        arm64|aarch64)
            if [[ "$os" == "darwin" ]]; then
                arch="arm64"
            else
                arch="aarch64"
            fi
            ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    # Set file extension
    if [[ "$os" == "windows" ]]; then
        ext="zip"
    else
        ext="tar.gz"
    fi
    
    echo "${os}-${arch}.${ext}"
}

# Get the latest release version (stable or prerelease)
get_latest_version() {
    local include_prerelease="${1:-false}"
    local api_response=""
    local version=""
    
    # Fetch releases from GitHub API
    if command -v curl >/dev/null 2>&1; then
        # Always fetch all releases to have full control over filtering
        api_response=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases?per_page=100" 2>&1)
    elif command -v wget >/dev/null 2>&1; then
        # Always fetch all releases to have full control over filtering
        api_response=$(wget -qO- "https://api.github.com/repos/${REPO}/releases?per_page=100" 2>&1)
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
    
    # Check if API call failed
    if [[ $? -ne 0 ]] || [[ -z "$api_response" ]]; then
        return 1
    fi
    
    # Try using jq if available (most reliable)
    if command -v jq >/dev/null 2>&1; then
        if [[ "$include_prerelease" == "true" ]]; then
            # Get first release (most recent, including prereleases)
            version=$(echo "$api_response" | jq -r '.[0].tag_name' 2>/dev/null)
        else
            # Get first stable release
            version=$(echo "$api_response" | jq -r '[.[] | select(.prerelease == false)][0].tag_name' 2>/dev/null)
        fi
        if [[ -n "$version" ]] && [[ "$version" != "null" ]]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Try using Python if available (reliable fallback)
    if command -v python3 >/dev/null 2>&1; then
        if [[ "$include_prerelease" == "true" ]]; then
            # Get first release (most recent, including prereleases)
            version=$(echo "$api_response" | python3 -c "import sys, json; releases = json.load(sys.stdin); print(releases[0]['tag_name'] if releases else '')" 2>/dev/null)
        else
            # Get first stable release
            version=$(echo "$api_response" | python3 -c "import sys, json; releases = json.load(sys.stdin); stable = [r for r in releases if not r.get('prerelease', False)]; print(stable[0]['tag_name'] if stable else '')" 2>/dev/null)
        fi
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback to grep/sed parsing (less reliable but works without dependencies)
    if [[ "$include_prerelease" == "true" ]]; then
        # Get first tag_name (most recent release)
        version=$(echo "$api_response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
    else
        # Parse JSON manually: find first release with "prerelease": false
        # Use grep with context to find tag_name near prerelease:false
        # First try looking backwards (tag_name usually comes before prerelease in JSON)
        version=$(echo "$api_response" | grep -B 30 '"prerelease":\s*false' | grep '"tag_name"' | tail -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
        # If that didn't work, try looking forwards
        if [[ -z "$version" ]]; then
            version=$(echo "$api_response" | grep -A 30 '"prerelease":\s*false' | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
        fi
    fi
    
    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    fi
    
    return 1
}

# Download and install
install_cli() {
    local platform_suffix=$(detect_platform)
    local os=$(echo "$platform_suffix" | cut -d'-' -f1)
    local arch=$(echo "$platform_suffix" | cut -d'-' -f2 | cut -d'.' -f1)
    
    print_status "Detected platform: $os ($arch)"
    
    # Get version if not specified
    if [[ "$VERSION" == "latest" ]]; then
        print_status "Fetching latest stable version..."
        VERSION=$(get_latest_version false)
        if [[ -z "$VERSION" ]]; then
            print_error "Failed to fetch latest version"
            exit 1
        fi
        print_status "Latest version: $VERSION"
    fi
    
    # Normalize version format (remove 'v' prefix if present, add it back for tag)
    local version_tag="$VERSION"
    if [[ "$version_tag" != v* ]]; then
        version_tag="v${version_tag}"
    fi
    
    # Construct download URL
    local filename="${BINARY_NAME}-${platform_suffix}"
    local download_url="https://github.com/${REPO}/releases/download/${version_tag}/${filename}"
    
    print_status "Downloading from: $download_url"
    
    # Create temporary directory
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Download the binary
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$download_url" -o "$tmp_dir/$filename"; then
            print_error "Failed to download binary"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q "$download_url" -O "$tmp_dir/$filename"; then
            print_error "Failed to download binary"
            exit 1
        fi
    else
        print_error "Neither curl nor wget is available"
        exit 1
    fi
    
    print_success "Downloaded binary successfully"
    
    # Extract and install based on OS
    if [[ "$os" == "windows" ]]; then
        install_windows "$tmp_dir/$filename"
    else
        install_unix "$tmp_dir/$filename" "$os"
    fi
}

# Install on Unix-like systems (macOS, Linux)
install_unix() {
    local archive_path="$1"
    local os="$2"
    
    print_status "Extracting archive..."
    
    # Extract the archive
    if ! tar -xzf "$archive_path" -C "$(dirname "$archive_path")"; then
        print_error "Failed to extract archive"
        exit 1
    fi
    
    # Determine install directory
    local install_dir="$HOME/.local/bin"
    
    # Create install directory if it doesn't exist
    mkdir -p "$install_dir"
    
    # Move binary to install directory
    # Note: The archive contains 'buster' directly, not 'buster-cli'
    local extract_dir="$(dirname "$archive_path")"
    local binary_path="$extract_dir/$INSTALL_NAME"
    if [[ ! -f "$binary_path" ]]; then
        # Fallback to old naming for backward compatibility
        binary_path="$extract_dir/$BINARY_NAME"
        if [[ ! -f "$binary_path" ]]; then
            print_error "Binary not found after extraction. Looked for both $INSTALL_NAME and $BINARY_NAME"
            exit 1
        fi
    fi
    
    if ! mv "$binary_path" "$install_dir/$INSTALL_NAME"; then
        print_error "Failed to move binary to $install_dir"
        exit 1
    fi
    
    # Make binary executable
    chmod +x "$install_dir/$INSTALL_NAME"
    
    # Copy node_modules directory if it exists (contains DuckDB native bindings)
    local node_modules_path="$extract_dir/node_modules"
    if [[ -d "$node_modules_path" ]]; then
        print_status "Installing DuckDB native bindings..."
        if ! cp -r "$node_modules_path" "$install_dir/"; then
            print_warning "Failed to copy DuckDB bindings. DuckDB features may not work."
        else
            print_success "DuckDB native bindings installed"
        fi
    else
        print_warning "node_modules directory not found in archive. DuckDB features may not work."
    fi
    
    print_success "Installed $INSTALL_NAME to $install_dir/$INSTALL_NAME"
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warning "$install_dir is not in your PATH"
        print_status "Add the following line to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):"
        echo
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        print_status "Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    else
        print_success "$install_dir is already in your PATH"
    fi
}

# Install on Windows (using Git Bash/MSYS2/Cygwin)
install_windows() {
    local archive_path="$1"
    
    print_status "Extracting archive..."
    
    # Extract zip file
    if ! unzip -q "$archive_path" -d "$(dirname "$archive_path")"; then
        print_error "Failed to extract archive"
        exit 1
    fi
    
    # Determine install directory (use Windows-friendly location)
    local install_dir="$LOCALAPPDATA/Microsoft/WindowsApps"
    
    # Create install directory if it doesn't exist
    mkdir -p "$install_dir"
    
    # Move binary to install directory
    # Note: The archive contains 'buster.exe' directly, not 'buster-cli.exe'
    local extract_dir="$(dirname "$archive_path")"
    local binary_path="$extract_dir/${INSTALL_NAME}.exe"
    if [[ ! -f "$binary_path" ]]; then
        # Fallback to old naming for backward compatibility
        binary_path="$extract_dir/${BINARY_NAME}.exe"
        if [[ ! -f "$binary_path" ]]; then
            print_error "Binary not found after extraction. Looked for both ${INSTALL_NAME}.exe and ${BINARY_NAME}.exe"
            exit 1
        fi
    fi
    
    if ! mv "$binary_path" "$install_dir/${INSTALL_NAME}.exe"; then
        print_error "Failed to move binary to $install_dir"
        exit 1
    fi
    
    # Copy node_modules directory if it exists (contains DuckDB native bindings)
    local node_modules_path="$extract_dir/node_modules"
    if [[ -d "$node_modules_path" ]]; then
        print_status "Installing DuckDB native bindings..."
        if ! cp -r "$node_modules_path" "$install_dir/"; then
            print_warning "Failed to copy DuckDB bindings. DuckDB features may not work."
        else
            print_success "DuckDB native bindings installed"
        fi
    else
        print_warning "node_modules directory not found in archive. DuckDB features may not work."
    fi
    
    print_success "Installed $INSTALL_NAME to $install_dir/${INSTALL_NAME}.exe"
    print_status "The binary should be available in your PATH automatically"
    print_status "You may need to restart your terminal for changes to take effect"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Wait a moment for PATH changes to take effect
    sleep 1
    
    if command -v "$INSTALL_NAME" >/dev/null 2>&1; then
        local version_output
        if version_output=$("$INSTALL_NAME" --version 2>/dev/null); then
            print_success "Installation verified! $version_output"
        else
            print_success "Installation successful! Binary is available as '$INSTALL_NAME'"
        fi
    else
        print_warning "Binary installed but not found in PATH. You may need to:"
        print_status "1. Restart your terminal"
        print_status "2. Add the install directory to your PATH"
        print_status "3. Run 'source ~/.bashrc' (or ~/.zshrc)"
    fi
}

# Main execution
main() {
    echo
    print_status "🚀 Buster CLI Installation Script"
    print_status "This script will download and install the latest Buster CLI binary"
    echo
    
    # Check for required tools
    if ! command -v tar >/dev/null 2>&1 && [[ "$(uname -s)" != "CYGWIN"* && "$(uname -s)" != "MINGW"* ]]; then
        print_error "tar is required but not installed"
        exit 1
    fi
    
    if [[ "$(uname -s)" == "CYGWIN"* || "$(uname -s)" == "MINGW"* ]]; then
        if ! command -v unzip >/dev/null 2>&1; then
            print_error "unzip is required but not installed"
            exit 1
        fi
    fi
    
    # Install the CLI
    install_cli
    
    # Verify installation
    verify_installation
    
    echo
    print_success "🎉 Installation complete!"
    print_status "You can now use the 'buster' command to interact with the Buster CLI"
    print_status "Try running: buster --help"
    echo
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --beta)
            print_status "Fetching latest beta version..."
            VERSION=$(get_latest_version true)
            if [[ -z "$VERSION" ]]; then
                print_error "Failed to fetch latest beta version"
                exit 1
            fi
            print_status "Latest beta version: $VERSION"
            shift
            ;;
        --help)
            echo "Buster CLI Installation Script"
            echo
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --version VERSION    Install specific version (default: latest stable)"
            echo "                       Examples: v4.1.0, v4.1.0-beta, 4.1.0-beta"
            echo "  --beta               Install latest beta/prerelease version"
            echo "  --help               Show this help message"
            echo
            echo "Examples:"
            echo "  $0                           # Install latest stable version"
            echo "  $0 --version v4.1.0           # Install specific stable version"
            echo "  $0 --version v4.1.0-beta      # Install specific beta version"
            echo "  $0 --version 4.1.0-beta      # Install specific beta version (without 'v')"
            echo "  $0 --beta                    # Install latest beta version"
            echo
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
