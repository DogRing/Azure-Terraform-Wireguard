#!/bin/bash

# Install WireGuard
sudo apt update && sudo apt upgrade -y
sudo apt install -y wireguard

# Update /etc/hosts to resolve host name issue
sudo sh -c 'echo "127.0.1.1 $(hostname)" >> /etc/hosts'

# Variables
SERVER_WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
SERVER_WG_CONFIG="$WG_DIR/$SERVER_WG_INTERFACE.conf"

sudo sysctl -w net.ipv4.ip_forward=1

# Server configuration
echo "[Interface]
PrivateKey = ${server_private_key}
Address = ${vpn_server_ip}
ListenPort = ${vpn_port}
${wg_peers}
" | sudo tee $SERVER_WG_CONFIG

# Start WireGuard
sudo wg-quick up $SERVER_WG_INTERFACE
sudo systemctl enable wg-quick@$SERVER_WG_INTERFACE

sudo iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT

sudo debconf-set-selections <<EOF
iptables-persistent iptables-persistent/autosave_v4 boolean true
iptables-persistent iptables-persistent/autosave_v6 boolean true
EOF
sudo apt-get -y install iptables-persistent

sudo ip route add $SERVER_VPN_IP dev wg0