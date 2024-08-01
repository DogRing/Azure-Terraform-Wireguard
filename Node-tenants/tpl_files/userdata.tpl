#!/bin/bash
sudo apt-get update && sudo apt-get upgrade -y

sudo snap install microk8s --classic --channel=1.30/stable

sudo ${microk8sAddNode}