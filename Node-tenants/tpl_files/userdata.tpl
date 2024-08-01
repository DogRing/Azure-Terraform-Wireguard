#!/bin/bash
sudo apt-get update && sudo apt-get upgrade -y

# docker 설치
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ${username}
newgrp docker

# kustomize 설치
sudo snap install kustomize

# microk8s 설치
sudo snap install microk8s --classic --channel=1.30/stable

sudo usermod -a -G microk8s dogring232
echo 'alias kubectl=microk8s.kubectl' >> ~/.bashrc
newgrp microk8s

# kind 설치
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
sudo mv ./kind /usr/local/bin/kind


# docker login
# kubectl create secret generic regcred \
#     --from-file=.dockerconfigjson=/home/dogring232/.docker/config.json \
#     --type=kubernetes.io/dockerconfigjson
# sudo sysctl fs.inotify.max_user_instances=2280
# sudo sysctl fs.inotify.max_user_watches=1255360
#  cat <<EOF | sudo kind create cluster --name=kubeflow --config=-
# kind: Cluster
# apiVersion: kind.x-k8s.io/v1alpha4
# nodes:
# - role: control-plane
#   image: kindest/node:v1.30.3
#   kubeadmConfigPatches:
#   - |
#     kind: ClusterConfiguration
#     apiServer:
#       extraArgs:
#         "service-account-issuer": "kubernetes.default.svc"
#         "service-account-signing-key-file": "/etc/kubernetes/pki/sa.key"
# EOF

# sudo kind get kubeconfig --name kubeflow > /tmp/kubeflow-config
# export KUBECONFIG=/tmp/kubeflow-config
# git clone https://github.com/kubeflow/manifests.git kubeflow
# cd kubeflow
# git checkout v1.9-branch
# while ! kustomize build example | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 20; done
# -----------------------------------------------------------------------------


# sudo ${microk8sAddNode}