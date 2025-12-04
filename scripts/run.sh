#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Clean up old interface
sudo ip link delete zeth 2>/dev/null || true

# Start app in background
sudo ./build/zephyr/zephyr.exe &
APP_PID=$!

# Wait for interface
sleep 1

# Configure networking
sudo ip addr add 192.0.2.1/24 dev zeth 2>/dev/null || true
sudo ip link set zeth up

# NAT setup
MAIN_IF=$(ip route | grep default | awk '{print $5}')
sudo sysctl -q -w net.ipv4.ip_forward=1
sudo iptables -t nat -C POSTROUTING -o $MAIN_IF -j MASQUERADE 2>/dev/null || \
    sudo iptables -t nat -A POSTROUTING -o $MAIN_IF -j MASQUERADE
sudo iptables -C FORWARD -i zeth -j ACCEPT 2>/dev/null || \
    sudo iptables -A FORWARD -i zeth -j ACCEPT

echo "Network configured. Attaching to app..."
wait $APP_PID
