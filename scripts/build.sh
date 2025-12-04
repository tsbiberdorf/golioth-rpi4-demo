#!/bin/bash
#
# Build script for Golioth demo on RPi4
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Activate venv if not already
if [ -z "$VIRTUAL_ENV" ]; then
    source "$REPO_ROOT/.venv/bin/activate"
fi

# Check for credentials
if [ -z "$GOLIOTH_PSK_ID" ] || [ -z "$GOLIOTH_PSK" ]; then
    echo "Error: Golioth credentials not set"
    echo ""
    echo "Run:"
    echo "  source credentials.env"
    echo ""
    exit 1
fi

cd "$REPO_ROOT"

echo "Building for native_sim..."
echo "  GOLIOTH_PSK_ID: $GOLIOTH_PSK_ID"
echo ""

# Build with 2 parallel jobs (safe for 1GB RAM + 2GB swap)
# Use -j 3 or -j 4 if you have more RAM/swap
west build -b native_sim app -j 2 -p auto -- \
    -DCONFIG_GOLIOTH_SAMPLE_PSK_ID=\"${GOLIOTH_PSK_ID}\" \
    -DCONFIG_GOLIOTH_SAMPLE_PSK=\"${GOLIOTH_PSK}\"

echo ""
echo "Build complete!"
echo ""
echo "Run with:"
echo "  ./build/zephyr/zephyr.exe"
echo ""
