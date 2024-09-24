#!/bin/bash
sudo apt -y update 

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo apt -y install ntp
sudo systemctl restart ntp
sudo ntpq -p
sudo sysctl -w net.ipv4.ip_forward=1

sudo tee -a /etc/hosts <<EOF
${hosts}
EOF

sudo cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
sudo cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo sh -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd.service

sudo cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo usermod -aG docker ${username}
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker
sudo systemctl restart containerd.service

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key |
 sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | 
 sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

sudo apt -y install kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet.service
sudo systemctl enable --now kubelet.service

mkdir -p /home/${username}/.kube
sudo apt install bash-completion -y

echo "source <(kubectl completion bash)
alias k=kubectl
alias kg='kubectl get'
alias kc='kubectl create'
alias ka='kubectl apply'
alias kr='kubectl run'
alias kd='kubectl delete'
complete -F __start_kubectl k" >> /home/${username}/.bashrc

sudo cat <<EOF | sudo tee /usr/local/bin/join-node.sh
#!/bin/bash
sleep 60
/usr/bin/${k8sAddNode}
EOF
sudo chmod +x /usr/local/bin/join-node.sh

sudo cat <<EOF | sudo tee /etc/systemd/system/k8s-join-node.service
[Unit]
Description=Run kubeadm join with delay

[Service]
ExecStart=/usr/local/bin/join-node.sh
Type=simple

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable k8s-join-node.service

sudo mkdir -p /DATA1/zk
sudo chown -R 1000:1000 /DATA1/zk
sudo chmod -R 755 /DATA1/zk

sudo reboot