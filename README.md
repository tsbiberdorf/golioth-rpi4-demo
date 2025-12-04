# Golioth RPi4 Demo

Run the Golioth Zephyr SDK on a Raspberry Pi 4 using Zephyr's `native_sim` board. This validates Golioth SDK integration without requiring target hardware.

## Purpose

This demo allows testing Golioth SDK functionality (connectivity, LightDB, OTA, etc.) on a Raspberry Pi 4 while waiting for target hardware (e.g., STM32 + cellular modem PPP) to be ready.

**What this validates:**
- Golioth cloud connectivity and device provisioning
- CoAP/DTLS communication
- LightDB State/Stream operations
- OTA update flows (file download)
- Your Golioth account/project configuration

**What this doesn't test:**
- Target MCU memory constraints
- PPP/modem driver integration
- Real cellular throughput

## Requirements

- Raspberry Pi 4 (1GB RAM minimum)
- Raspberry Pi OS Lite (headless OK)
- Network connectivity (Ethernet or WiFi)
- Golioth account and device credentials

## Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/tsbiberdorf/golioth-rpi4-demo.git
cd golioth-rpi4-demo
```

### 2. Run setup script

```bash
chmod +x scripts/setup-rpi.sh
./scripts/setup-rpi.sh
```

This will:
- Configure 2GB swap (needed for builds on 1GB Pi)
- Install system dependencies
- Create Python virtual environment
- Initialize west workspace
- Download Zephyr + Golioth SDK (~10-15 minutes)
- Install Zephyr SDK toolchain

### 3. Configure Golioth credentials

Get your device credentials from [Golioth Console](https://console.golioth.io):

```bash
# Edit credentials.env with your PSK-ID and PSK
nano credentials.env
```

### 4. Build

```bash
source .venv/bin/activate
source credentials.env
./scripts/build.sh
```

Build takes ~7-9 minutes on a 1GB Pi with `-j 2`.

### 5. Run

```bash
./build/zephyr/zephyr.exe
```

You should see:
```
[00:00:00.000,000] <inf> golioth_demo: Golioth RPi4 Demo Starting
[00:00:00.000,000] <inf> golioth_demo: Waiting for connection to Golioth...
[00:00:02.xxx,xxx] <inf> golioth_demo: Golioth client connected!
[00:00:02.xxx,xxx] <inf> golioth_demo: Hello from RPi4! Counter: 0
```

Check the Golioth Console to see your device online and `counter` updating in LightDB State.

## Memory Considerations (1GB Pi)

The default build uses `-j 2` parallel jobs, which is safe for 1GB RAM + 2GB swap.

| RAM | Swap | Recommended -j |
|-----|------|----------------|
| 1GB | 512MB | 1 |
| 1GB | 2GB | 2 |
| 2GB+ | any | 3-4 |

To monitor memory during builds:
```bash
watch -n 1 free -h
```

## Project Structure

```
golioth-rpi4-demo/
├── west.yml              # West manifest (pins SDK versions)
├── app/
│   ├── CMakeLists.txt
│   ├── prj.conf          # Zephyr/Golioth configuration
│   ├── boards/
│   │   └── native_sim.conf
│   └── src/
│       └── main.c
├── scripts/
│   ├── setup-rpi.sh      # One-time setup
│   └── build.sh          # Build script
├── credentials.env       # Your Golioth credentials (git-ignored)
└── README.md
```

## Adding File Download Sample

To test OTA/file download functionality, modify `main.c` to use Golioth's OTA or FW Update APIs. See the [Golioth Firmware SDK samples](https://github.com/golioth/golioth-firmware-sdk/tree/main/examples/zephyr) for examples.

## Transitioning to Target Hardware

When your STM32 + PPP stack is ready:

1. Create a new board overlay: `app/boards/nucleo_u385rg_q.conf`
2. Build for target: `west build -b nucleo_u385rg_q app`
3. The same `prj.conf` and `main.c` work on both platforms

Key additions needed for target:
- PPP driver configuration
- Modem UART settings
- Flash partitioning for MCUBoot (if using OTA)

## Troubleshooting

### Build fails with OOM
Reduce parallel jobs:
```bash
west build -b native_sim app -j 1
```

### Connection timeout
- Verify credentials in `credentials.env`
- Check network connectivity: `ping coap.golioth.io`
- Ensure device exists in Golioth Console

### "west: command not found"
Activate the virtual environment:
```bash
source .venv/bin/activate
```

## License

Apache-2.0
