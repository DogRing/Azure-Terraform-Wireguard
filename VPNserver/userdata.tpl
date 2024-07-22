#!/bin/bash

# Install WireGuard
sudo apt update && sudo apt upgrade -y
sudo apt install -y wireguard

# Update /etc/hosts to resolve host name issue
sudo sh -c 'echo "127.0.1.1 $(hostname)" >> /etc/hosts'

# Variables
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo $SERVER_PRIVATE_KEY | wg pubkey)
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
SERVER_IP=${server_ip}
SERVER_PORT=${vpn_port}
SERVER_WG_INTERFACE="wg0"

SERVER_VPN_IP="10.255.255.128/25"
CLIENT_VPN_IP="10.255.255.129/25"
CLIENT_NETWORK="192.168.0.0/24"

WG_DIR="/etc/wireguard"
SERVER_WG_CONFIG="$WG_DIR/$SERVER_WG_INTERFACE.conf"
CLIENT_WG_CONFIG="$WG_DIR/client.conf"

sudo sysctl -w net.ipv4.ip_forward=1

echo "[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $SERVER_VPN_IP
ListenPort = $SERVER_PORT

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_VPN_IP, $CLIENT_NETWORK
" | sudo tee $SERVER_WG_CONFIG

# Generate client configuration
echo "[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_VPN_IP
DNS = 168.126.63.2

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$SERVER_PORT 
AllowedIPs = 10.0.0.0/8
" | sudo tee $CLIENT_WG_CONFIG

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