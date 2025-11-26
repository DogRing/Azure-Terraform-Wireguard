#!/bin/bash

# Update system and install Wireguard
sudo apt update && sudo apt upgrade -y
sudo apt install -y wireguard

# Update /etc/hosts to resolve hostname issue
sudo sh -c 'echo "127.0.1.1 $(hostname)" >> /etc/hosts'

# Variables
SERVER_WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
SERVER_WG_CONFIG="$WG_DIR/$SERVER_WG_INTERFACE.conf"

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Create Wireguard server configuration
echo "[Interface]
PrivateKey = ${server_private_key}
Address = ${vpn_server_ip}
ListenPort = ${vpn_port}
${wg_peers}
" | sudo tee $SERVER_WG_CONFIG

# Set permissions
sudo chmod 600 $SERVER_WG_CONFIG

# Configure iptables for forwarding
sudo iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o ens3 -j ACCEPT

# Make iptables rules persistent
sudo debconf-set-selections <<EOF
iptables-persistent iptables-persistent/autosave_v4 boolean true
iptables-persistent iptables-persistent/autosave_v6 boolean true
EOF
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent

# Start Wireguard
sudo wg-quick up $SERVER_WG_INTERFACE
sudo systemctl enable wg-quick@$SERVER_WG_INTERFACE

# Verify Wireguard is running
sudo wg show

echo "Wireguard VPN server setup completed successfully!"
