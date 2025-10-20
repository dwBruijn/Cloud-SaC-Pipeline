#!/bin/bash
# Install additional security scanning tools

set -e

echo "Installing additional security tools..."

# Detect OS
OS="$(uname -s)"

# Install tfsec
echo "Installing tfsec..."
case "$OS" in
    Linux*)
        curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
        ;;
    Darwin*)
        brew install tfsec
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Verify installations
echo ""
echo "Verifying installations..."
echo "tfsec version: $(tfsec --version)"

echo ""
echo "✓ All tools installed successfully!"
echo ""
echo "You can now run: python scripts/scan.py --path terraform/vulnerable-examples"