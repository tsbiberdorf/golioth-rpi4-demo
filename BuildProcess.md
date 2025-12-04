# Build Process Guide

This document captures the complete setup and build process for the Golioth RPi4 Demo on a Raspberry Pi 4 (1GB RAM).

## Prerequisites

- Raspberry Pi 4 (1GB+ RAM) running Raspberry Pi OS Lite (Bookworm)
- Network connectivity
- Golioth account with device credentials

## Initial Setup

### 1. Clone Repository
```bash
cd ~
git clone https://github.com/tsbiberdorf/golioth-rpi4-demo.git
cd golioth-rpi4-demo
```

### 2. Expand Swap (Required for 1GB Pi)
```bash
sudo swapoff -a 2>/dev/null || true
sudo rm -f /swapfile
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify (should show ~2GB)
free -h
```

### 3. Install System Dependencies
```bash
sudo apt update
sudo apt install -y --no-install-recommends \
    git cmake ninja-build gperf ccache dfu-util device-tree-compiler \
    wget python3-dev python3-pip python3-setuptools python3-tk \
    python3-wheel python3-venv xz-utils file make gcc g++ \
    libsdl2-dev libmagic1 iptables libcoap3-bin
```

> **Note:** Do NOT install `gcc-multilib` or `g++-multilib` — these are x86-only packages and not available on ARM64.

### 4. Create Python Virtual Environment
```bash
cd ~/golioth-rpi4-demo
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip wheel setuptools
pip install west
```

### 5. Initialize West Workspace
```bash
west init -l app
west update
```

> **Note:** `west update` takes 10-15 minutes. It downloads Zephyr, Golioth SDK, and all modules.

### 6. Initialize Golioth SDK Submodules

The Golioth SDK has external dependencies (bsdiff, etc.) that must be initialized:
```bash
cd ~/golioth-rpi4-demo/modules/lib/golioth-firmware-sdk
git submodule update --init --recursive
cd ~/golioth-rpi4-demo
```

### 7. Export Zephyr and Install Python Requirements
```bash
west zephyr-export
pip install -r zephyr/scripts/requirements.txt
```

### 8. Install Zephyr SDK
```bash
cd ~
wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.8/zephyr-sdk-0.16.8_linux-aarch64_minimal.tar.xz
tar xf zephyr-sdk-0.16.8_linux-aarch64_minimal.tar.xz
rm zephyr-sdk-0.16.8_linux-aarch64_minimal.tar.xz
cd zephyr-sdk-0.16.8
./setup.sh -h
```

## Building

### 1. Configure Credentials

**IMPORTANT:** The PSK-ID must include your project name in the format `devicename@projectname`.

Get your credentials from [Golioth Console](https://console.golioth.io):
1. Navigate to your project → Devices → your device
2. Click "Credentials" tab
3. Copy the full "Identity (PSK-ID)" — it will be in format `devicename@projectname`
4. Copy the "Pre-Shared Key (PSK)"

Create credentials file:
```bash
cd ~/golioth-rpi4-demo
cat > credentials.env << 'CRED_EOF'
export GOLIOTH_PSK_ID="yourdevice@yourproject"
export GOLIOTH_PSK="your-psk-hex-string"
CRED_EOF
```

Edit with your actual Golioth credentials:
```bash
nano credentials.env
```

Example (do not use these values):
```bash
export GOLIOTH_PSK_ID="genevaDevice@genevafiles"
export GOLIOTH_PSK="b3642ca75684b5a2b967f7d98601df88"
```

### 2. Verify Credentials (Optional)

Test connectivity before building:
```bash
coap-client-gnutls -m get \
  -u "yourdevice@yourproject" \
  -k "your-psk" \
  "coaps://coap.golioth.io/hello"
```

Expected output: `Hello yourdevice`

### 3. Build
```bash
source .venv/bin/activate
source credentials.env
./scripts/build.sh
```

Build takes approximately 7-9 minutes with `-j 2` on a 1GB Pi.

> **Note:** The build uses `native_sim/native/64` target for 64-bit ARM (aarch64) hosts like RPi4.

### 4. Run
```bash
./scripts/run.sh
```

> **Note:** The run script handles TAP interface setup and requires sudo internally.

Expected output:
```
WARNING: Using a test - not safe - entropy source
uart connected to pseudotty: /dev/pts/X
*** Booting Zephyr OS build v3.7.0 ***
[00:00:00.000,000] <inf> golioth_demo: Golioth RPi4 Demo Starting
[00:00:00.000,000] <err> golioth_sys_zephyr: eventfd creation failed, errno: 22
[00:00:00.000,000] <inf> golioth_mbox: Mbox created, bufsize: 1848, num_items: 10, item_size: 168
[00:00:00.000,000] <inf> golioth_demo: Waiting for connection to Golioth...
Network configured. Attaching to app...
[00:00:07.320,000] <inf> golioth_coap_client_zephyr: Golioth CoAP client connected
[00:00:07.320,000] <inf> golioth_demo: Golioth client connected!
[00:00:07.320,000] <inf> golioth_demo: Hello from RPi4! Counter: 0
```

> **Note:** The `eventfd creation failed` errors are cosmetic and do not affect operation.

Use `Ctrl+C` to stop.

## Bidirectional Communication Demo

This demo shows data flowing both directions between device and cloud.

### Device → Cloud (Send Data)

In a **second terminal**, run the data sender:
```bash
~/golioth-rpi4-demo/scripts/send-data.sh
```

This sends counter data to LightDB State every 10 seconds.

**View in Console:**
1. Go to [Golioth Console](https://console.golioth.io)
2. Navigate to Devices → your device → **LightDB State** tab
3. See the `state` object updating:
```json
   {
     "state": {
       "counter": 5,
       "source": "RPi4"
     }
   }
```

### Cloud → Device (Receive Data)

**Set data in Console:**
1. In **LightDB State** tab, edit the JSON to add a `config` section:
```json
   {
     "state": {
       "counter": 5,
       "source": "RPi4"
     },
     "config": {
       "message": "Hello from cloud!",
       "interval": 5
     }
   }
```
2. Click **Save**

**Read from device:**
```bash
source ~/golioth-rpi4-demo/credentials.env
coap-client-gnutls -m get \
  -u "$GOLIOTH_PSK_ID" \
  -k "$GOLIOTH_PSK" \
  "coaps://coap.golioth.io/.d/config"
```

Expected output:
```json
{"message":"Hello from cloud!","interval":5}
```

## Complete Demo Setup

For a full demonstration, use two SSH terminals:

**Terminal 1 — Zephyr Connection:**
```bash
cd ~/golioth-rpi4-demo
source .venv/bin/activate
source credentials.env
./scripts/run.sh
```

**Terminal 2 — Data Operations:**
```bash
# Send data to cloud (runs continuously)
~/golioth-rpi4-demo/scripts/send-data.sh

# Or read config from cloud (one-shot)
source ~/golioth-rpi4-demo/credentials.env
coap-client-gnutls -m get \
  -u "$GOLIOTH_PSK_ID" \
  -k "$GOLIOTH_PSK" \
  "coaps://coap.golioth.io/.d/config"
```

**In Golioth Console, show:**

| Feature | Console Location | Description |
|---------|------------------|-------------|
| Device online | Summary tab | Session Established timestamp |
| Data from device | LightDB State → `state` | Counter updating |
| Data to device | LightDB State → `config` | Edit JSON, device reads |

## Quick Start (After Initial Setup)
```bash
# Terminal 1
cd ~/golioth-rpi4-demo
source .venv/bin/activate
source credentials.env
./scripts/run.sh

# Terminal 2
~/golioth-rpi4-demo/scripts/send-data.sh
```

## Rebuilding

### Clean Rebuild
```bash
rm -rf build
source .venv/bin/activate
source credentials.env
./scripts/build.sh
```

### Incremental Rebuild

If only source files changed:
```bash
source .venv/bin/activate
source credentials.env
west build
```

## What This Demo Validates

**Proves working:**
- Golioth cloud connectivity and device provisioning
- CoAP/DTLS communication
- Zephyr SDK integration
- Device appears online in Golioth Console
- Bidirectional data flow (device ↔ cloud)

**Does not test:**
- Target MCU memory constraints
- PPP/modem driver integration
- Real cellular throughput
- Production flash partitioning
- OTA firmware updates (requires MCUboot on real hardware)
- Settings service (has threading issues on native_sim/aarch64)

## Troubleshooting

### OOM During Build

Reduce parallelism by editing `scripts/build.sh`:
```bash
export CMAKE_BUILD_PARALLEL_LEVEL=1
```

Or add more swap.

### Missing bspatch.c or Golioth SDK Source Files

Initialize the Golioth SDK submodules:
```bash
cd ~/golioth-rpi4-demo/modules/lib/golioth-firmware-sdk
git submodule update --init --recursive
cd ~/golioth-rpi4-demo
rm -rf build
./scripts/build.sh
```

### CONFIG_64BIT Error on RPi4

The RPi4 runs 64-bit Linux. Use `native_sim/native/64` board target (already configured in `scripts/build.sh`).

### PSK-ID Format Error / DTLS Handshake Failure

The PSK-ID must include the project name:
- **Wrong:** `genevaDevice`
- **Correct:** `genevaDevice@genevafiles`

Check the Golioth Console → Devices → Credentials tab for the full Identity string.

### Kconfig Warnings About Credentials

Ensure `app/prj.conf` contains:
```
CONFIG_GOLIOTH_SAMPLE_HARDCODED_CREDENTIALS=y
```

**Not** `CONFIG_GOLIOTH_SAMPLE_SETTINGS=y`.

### "west: command not found"

Activate the virtual environment:
```bash
source .venv/bin/activate
```

### Network Errors: "Cannot create zeth" or "Fail to get address"

Use the run script which handles network setup:
```bash
./scripts/run.sh
```

### "iptables: command not found"
```bash
sudo apt install -y iptables
```

### "coap-client-gnutls: command not found"
```bash
sudo apt install -y libcoap3-bin
```

### Connection Timeout After Network Setup

- Verify credentials format: `device@project`
- Test with coap-client: `coap-client-gnutls -m get -u "device@project" -k "psk" "coaps://coap.golioth.io/hello"`
- Check device exists in [Golioth Console](https://console.golioth.io)

### eventfd Errors

The following errors are cosmetic on native_sim/aarch64 and do not affect operation:
```
<err> golioth_sys_zephyr: eventfd creation failed, errno: 22
```

### west.yml Location

The `west.yml` manifest must be in `app/` directory, not the repo root.

## Directory Structure After Setup
```
~/golioth-rpi4-demo/
├── app/                    # Application code (in git)
│   ├── west.yml
│   ├── CMakeLists.txt
│   ├── prj.conf
│   ├── boards/
│   │   └── native_sim.conf
│   └── src/
│       └── main.c
├── zephyr/                 # Zephyr RTOS (fetched by west)
├── modules/                # Golioth SDK + HALs (fetched by west)
│   └── lib/
│       └── golioth-firmware-sdk/
│           └── external/   # Submodules (bsdiff, etc.)
├── bootloader/             # MCUboot (fetched by west)
├── build/                  # Build output
├── .venv/                  # Python virtual environment
├── credentials.env         # Golioth credentials (git-ignored)
├── scripts/
│   ├── setup-rpi.sh
│   ├── setup-net.sh
│   ├── build.sh
│   ├── run.sh
│   └── send-data.sh
└── README.md
```

## Memory Reference

| Pi RAM | Swap | Recommended Parallelism |
|--------|------|-------------------------|
| 1GB    | 512MB | `-j 1` |
| 1GB    | 2GB   | `-j 2` |
| 2GB+   | any   | `-j 3` or `-j 4` |

Monitor during build:
```bash
watch -n 2 free -h
```

## Updating Dependencies
```bash
cd ~/golioth-rpi4-demo
source .venv/bin/activate
west update
cd modules/lib/golioth-firmware-sdk
git submodule update --init --recursive
cd ~/golioth-rpi4-demo
pip install -r zephyr/scripts/requirements.txt
rm -rf build
./scripts/build.sh
```

## Transitioning to Target Hardware

When your STM32 + PPP stack is ready:

1. Create a new board overlay: `app/boards/nucleo_u385rg_q.conf`
2. Update `scripts/build.sh` to use your target board
3. Build for target: `west build -b nucleo_u385rg_q app`
4. The same `prj.conf` and `main.c` work on both platforms

Key additions needed for target hardware:
- PPP driver configuration
- Modem UART settings  
- Flash partitioning for MCUBoot (if using OTA)
- Remove hardcoded credentials, use settings subsystem

## Scripts Reference

### build.sh
Builds the Zephyr application for native_sim/native/64.

### run.sh
Sets up TAP network interface and runs the Zephyr executable with proper networking.

### send-data.sh
Sends counter data to Golioth LightDB State every 10 seconds using coap-client.

### setup-rpi.sh
One-time setup script for fresh RPi4 (swap, dependencies, west init).

### setup-net.sh
Manual network setup (called automatically by run.sh).
