#!/bin/bash
sudo apt-get update

# Kubernetes 설치
sudo snap install microk8s --classic --channel=1.30/stable

# Kubernetes 연결
sudo ${microk8sAddNode}
