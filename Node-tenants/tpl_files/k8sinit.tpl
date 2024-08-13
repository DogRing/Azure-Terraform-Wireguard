#!/bin/bash
sudo apt -y update 

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo apt -y install ntp
sudo systemctl restart ntp
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

# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key |
# sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | 
# sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key |
 sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | 
 sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

sudo apt -y install kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl



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

sudo mkdir -p /DATA1

sudo reboot

sudo kubeadm init --pod-network-cidr=10.96.0.0/12 --apiserver-advertise-address=192.168.0.9
sudo kubeadm init --pod-network-cidr=10.96.0.0/12 --apiserver-advertise-address=10.13.1.4
# join 토큰
# kubeadm token create --print-join-command
sudo cp /etc/kubernetes/admin.conf /home/${username}/.kube/config
sudo chown $(id -u):$(id -g) /home/${username}/.kube/config

# calico 설치
# kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/calico.yaml

# dashboard 설치
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

## Dashboard 생성을 위한 SA 생성과 권한 부여 namespace: dashboard 에 만들어 놓음
mkdir dashboard_rbac && cd $_
echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
" > dashboard-admin-user.yaml

echo "apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
" > ClusterRoleBinding-admin-user.yml

kubectl apply -f dashboard-admin-user.yaml
kubectl apply -f ClusterRoleBinding-admin-user.yml

# SA 토큰 확인
kubectl -n kubernetes-dashboard create token admin-user

# cert와 key 생성
grep 'client-certificate-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> kubecfg.crt
grep 'client-key-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> kubecfg.key

# 키를 기반으로 p12 인증서 파일 생성 (인증서 암호 설정)
openssl pkcs12 -export -clcerts -inkey kubecfg.key -in kubecfg.crt -out kubecfg.p12 -name "kubernetes-admin"

# 클러스터 생성시 가지는 인증서
sudo cp /etc/kubernetes/pki/ca.crt  ./

# kubeshark
sh <(curl -Ls https://kubeshark.co/install)
ks tap # 클러스터 내 패패킷을 캡쳐

sudo mkdir -p /DATA1
# kubectl create ns portainer
echo "apiVersion: v1
kind: PersistentVolume
metadata:
  name: portainer-pv
  namespace: portainer
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  local:
    path: /DATA1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - {key: kubernetes.io/hostname, operator: In, values: [vm-gpu-node-0]}
" > portainer-pv.yaml
kubectl apply -n portainer -f portainer-pv.yaml
# /DATA1 의 경로가 없을 수 있다. 

# Portainer LB
kubectl apply -n portainer -f https://raw.githubusercontent.com/portainer/k8s/master/deploy/manifests/portainer/portainer-lb.yaml

# Portainer Nodeport
kubectl apply -n portainer -f https://raw.githubusercontent.com/portainer/k8s/master/deploy/manifests/portainer/portainer.yaml

# portainer 창 오류 시
kubectl rollout restart deployment -n portainer portainer
