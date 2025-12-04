#!/bin/bash
# Setup TAP interface for native_sim

# Create TAP interface
sudo ip tuntap add dev zeth mode tap user $USER
sudo ip link set zeth up

# Give it an IP on a private subnet
sudo ip addr add 192.0.2.1/24 dev zeth

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# NAT the traffic out through the Pi's main interface
MAIN_IF=$(ip route | grep default | awk '{print $5}')
sudo iptables -t nat -A POSTROUTING -o $MAIN_IF -j MASQUERADE
sudo iptables -A FORWARD -i zeth -j ACCEPT
sudo iptables -A FORWARD -o zeth -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Network setup complete. zeth interface ready."
echo "Main interface: $MAIN_IF"
ip addr show zeth
