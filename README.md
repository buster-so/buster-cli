# Buster CLI

The official command-line interface for Buster.

## Installation

### Quick Install (Recommended)

#### macOS/Linux
```bash
# Install latest stable version
curl -fsSL https://platform.buster.so/cli | bash

# Install specific version
curl -fsSL https://platform.buster.so/cli | bash -- --version v4.1.0

# Install latest beta version
curl -fsSL https://platform.buster.so/cli | bash -- --beta

# Install specific beta version
curl -fsSL https://platform.buster.so/cli | bash -- --version v4.1.0-beta
```

#### Windows (PowerShell)
```powershell
# Install latest stable version
irm https://platform.buster.so/cli | iex

# Install specific version
irm https://platform.buster.so/cli | iex -- --version v4.1.0

# Install latest beta version
irm https://platform.buster.so/cli | iex -- --beta

# Install specific beta version
irm https://platform.buster.so/cli | iex -- --version v4.1.0-beta
```

### Installation Options

- **Default**: Installs the latest stable release
- **`--version VERSION`**: Install a specific version (e.g., `v4.1.0`, `v4.1.0-beta`, `4.1.0-beta`)
- **`--beta`**: Install the latest beta/prerelease version
- **`--help`**: Show installation help

### Manual Installation

Download the latest release for your platform from the [releases page](https://github.com/buster-so/buster-cli/releases).

**Note**: Beta releases are marked as prereleases on GitHub. To install a beta version, use the `--version` flag with the beta tag (e.g., `v4.1.0-beta`).

## Usage

```bash
buster --help
```

## Documentation

For full documentation, visit [docs.buster.so](https://docs.buster.so).

## License

Copyright © 2024 Buster Technologies, Inc. All rights reserved.

This software is proprietary and confidential. Unauthorized copying, modification, distribution, or use of this software, via any medium, is strictly prohibited.

See [LICENSE](LICENSE) for full terms.
