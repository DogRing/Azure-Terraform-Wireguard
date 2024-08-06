#!/bin/bash
sudo apt-get update && sudo apt-get upgrade -y

# microk8s 설치
sudo snap install microk8s --classic --channel=1.30/stable

sudo ${microk8sAddNode} --worker