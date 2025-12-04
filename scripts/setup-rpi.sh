#!/bin/bash
#
# Golioth RPi4 Demo Setup Script
# Configures a Raspberry Pi 4 (1GB) for Zephyr native_sim builds
#
set -e

echo "=== Golioth RPi4 Demo Setup ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running on RPi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    warn "This doesn't appear to be a Raspberry Pi. Continuing anyway..."
fi

# Get the repo root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

info "Repository root: $REPO_ROOT"

# Step 1: Setup swap if needed
info "Checking swap configuration..."
TOTAL_SWAP=$(free -m | awk '/Swap:/ {print $2}')
if [ "$TOTAL_SWAP" -lt 1500 ]; then
    info "Current swap: ${TOTAL_SWAP}MB. Expanding to 2GB..."
    
    # Disable existing swap
    sudo swapoff -a 2>/dev/null || true
    
    # Remove old swapfile if exists
    sudo rm -f /swapfile
    
    # Create new 2GB swapfile
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    
    # Make permanent if not already in fstab
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    
    info "Swap configured: $(free -m | awk '/Swap:/ {print $2}')MB"
else
    info "Swap already sufficient: ${TOTAL_SWAP}MB"
fi

# Step 2: Install system dependencies
info "Installing system dependencies..."
sudo apt update
sudo apt install -y --no-install-recommends \
    git \
    cmake \
    ninja-build \
    gperf \
    ccache \
    dfu-util \
    device-tree-compiler \
    wget \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-tk \
    python3-wheel \
    python3-venv \
    xz-utils \
    file \
    make \
    gcc \
    gcc-multilib \
    g++-multilib \
    libsdl2-dev \
    libmagic1

# Step 3: Setup Python virtual environment
info "Setting up Python virtual environment..."
VENV_DIR="$REPO_ROOT/.venv"

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

pip install --upgrade pip wheel setuptools
pip install west

# Step 4: Initialize west workspace
info "Initializing west workspace..."
cd "$REPO_ROOT"

if [ ! -d ".west" ]; then
    west init -l app
else
    info "West already initialized"
fi

# Step 5: Update west modules
info "Updating west modules (this may take 10-15 minutes)..."
west update

# Step 6: Export Zephyr CMake package
info "Exporting Zephyr..."
west zephyr-export

# Step 7: Install Python requirements
info "Installing Zephyr Python requirements..."
pip install -r zephyr/scripts/requirements.txt

# Step 8: Install Zephyr SDK (host tools only for native_sim)
info "Checking Zephyr SDK..."
ZEPHYR_SDK_VERSION="0.16.8"
SDK_DIR="$HOME/zephyr-sdk-${ZEPHYR_SDK_VERSION}"

if [ ! -d "$SDK_DIR" ]; then
    info "Installing Zephyr SDK ${ZEPHYR_SDK_VERSION}..."
    cd "$HOME"
    
    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        SDK_ARCH="aarch64"
    elif [ "$ARCH" = "x86_64" ]; then
        SDK_ARCH="x86_64"
    else
        error "Unsupported architecture: $ARCH"
    fi
    
    SDK_FILE="zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-${SDK_ARCH}_minimal.tar.xz"
    SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/${SDK_FILE}"
    
    wget -q --show-progress "$SDK_URL"
    tar xf "$SDK_FILE"
    rm "$SDK_FILE"
    
    cd "$SDK_DIR"
    ./setup.sh -h  # Host tools only
else
    info "Zephyr SDK already installed"
fi

# Step 9: Create credentials template
info "Creating credentials template..."
CREDS_FILE="$REPO_ROOT/credentials.env"
if [ ! -f "$CREDS_FILE" ]; then
    cat > "$CREDS_FILE" << 'EOF'
# Golioth Device Credentials
# Get these from: https://console.golioth.io
# 
# Option 1: PSK authentication
export GOLIOTH_PSK_ID="your-device-id"
export GOLIOTH_PSK="your-psk"

# Option 2: Certificate authentication (if using)
# export GOLIOTH_CERT_PATH="/path/to/client.crt"
# export GOLIOTH_KEY_PATH="/path/to/client.key"
EOF
    warn "Created credentials.env - edit this file with your Golioth credentials"
else
    info "credentials.env already exists"
fi

# Done
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Edit credentials.env with your Golioth device credentials"
echo ""
echo "  2. Activate the virtual environment:"
echo "     source .venv/bin/activate"
echo ""
echo "  3. Source your credentials:"
echo "     source credentials.env"
echo ""
echo "  4. Build the demo:"
echo "     ./scripts/build.sh"
echo ""
echo "  5. Run:"
echo "     ./build/zephyr/zephyr.exe"
echo ""
