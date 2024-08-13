#!/bin/bash
sudo apt-get update && sudo apt-get upgrade -y
sudo sysctl -w net.ipv4.ip_forward=1

sudo echo "
${hosts}
" > /etc/hosts

# microk8s 설치
sudo snap install microk8s --classic --channel=1.30/stable

sudo ${microk8sAddNode} --worker