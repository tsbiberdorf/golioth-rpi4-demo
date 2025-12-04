#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -z "$VIRTUAL_ENV" ]; then
    source "$REPO_ROOT/.venv/bin/activate"
fi

if [ -z "$GOLIOTH_PSK_ID" ] || [ -z "$GOLIOTH_PSK" ]; then
    echo "Error: Golioth credentials not set"
    echo "Run: source credentials.env"
    exit 1
fi

cd "$REPO_ROOT"

echo "Building for native_sim/native/64..."
echo "  GOLIOTH_PSK_ID: $GOLIOTH_PSK_ID"

export CMAKE_BUILD_PARALLEL_LEVEL=2

west build -b native_sim/native/64 app -p auto \
    -DCONFIG_GOLIOTH_SAMPLE_PSK_ID=\"${GOLIOTH_PSK_ID}\" \
    -DCONFIG_GOLIOTH_SAMPLE_PSK=\"${GOLIOTH_PSK}\"

echo ""
echo "Build complete!"
echo "Run with: ./build/zephyr/zephyr.exe"
