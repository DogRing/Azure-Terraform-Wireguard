# Wireguard VPN 디버깅 가이드

연결이 안 될 때 단계별로 확인하는 체계적인 디버깅 가이드입니다.

---

## 🔍 1단계: 문제 증상 확인

먼저 어느 단계에서 문제가 발생하는지 확인합니다.

### 체크리스트
- [ ] Terraform apply가 성공했는가?
- [ ] VPN 서버에 SSH 접속이 되는가?
- [ ] Wireguard 클라이언트가 연결을 시도하는가?
- [ ] Handshake가 발생하는가?
- [ ] Ping이 되는가?

---

## 🔧 2단계: Terraform 배포 상태 확인

### 1. Terraform 출력 확인
```bash
cd OCI-Wireguard/VPN-server
terraform output

# 다음 정보가 모두 출력되어야 함:
# - vpn_public_ip
# - vpn_private_ip
# - instance_id
# - vcn_id
# - subnet_id
```

### 2. Terraform State 확인
```bash
# Compute Instance 상태
terraform state show 'module.wireguard.oci_core_instance.main'

# 다음 항목 확인:
# - state = "RUNNING"
# - create_vnic_details.skip_source_dest_check = true
# - create_vnic_details.assign_public_ip = true
```

### 3. OCI Console에서 확인
```
OCI Console → Compute → Instances
- Instance 상태: Running
- Public IP: 할당됨
- VNIC 확인: Primary VNIC에 Public IP 있는지
```

**문제 발견 시:**
```bash
# Instance 재생성
terraform taint 'module.wireguard.oci_core_instance.main'
terraform apply
```

---

## 🌐 3단계: 네트워크 연결성 확인

### 1. VPN 서버 Public IP Ping 테스트
```bash
# 클라이언트에서
ping <VPN_PUBLIC_IP>
```

**Ping 안되면:**
- OCI Console → VCN → Security Lists 확인
- ICMP (Protocol 1) 허용되어 있는지 확인

```bash
cd OCI-Wireguard/VPN-server
terraform console
```
```hcl
# Security List에 ICMP 추가
module.network.oci_core_security_list.main.ingress_security_rules
```

### 2. SSH 접속 테스트
```bash
# VPN 서버 SSH 접속
ssh -v ubuntu@<VPN_PUBLIC_IP>
```

**SSH 안되면:**

#### Option A: terraform.tfvars에 SSH 허용 추가
```hcl
enable_ssh = ["YOUR_PUBLIC_IP/32"]
```

본인 공인 IP 확인:
```bash
curl ifconfig.me
```

적용:
```bash
terraform apply
```

#### Option B: OCI Console에서 수동 추가
```
OCI Console → Networking → Virtual Cloud Networks
→ VPN VCN → Security Lists → Default Security List
→ Add Ingress Rules:
  - Source CIDR: YOUR_IP/32
  - IP Protocol: TCP
  - Destination Port: 22
```

### 3. Wireguard 포트 확인
```bash
# VPN 서버에서
sudo netstat -ulnp | grep 51820
```

**출력 예시 (정상):**
```
udp        0      0 0.0.0.0:51820           0.0.0.0:*                           12345/wg
```

**포트가 안 열려 있으면:**
```bash
# Wireguard 상태 확인
sudo systemctl status wg-quick@wg0

# 로그 확인
sudo journalctl -u wg-quick@wg0 -n 50
```

---

## 🔐 4단계: Security Rules 확인

### 1. NSG (Network Security Group) 확인

**OCI Console:**
```
Networking → Virtual Cloud Networks → VPN VCN
→ Network Security Groups → nsg-wireguard-vpn
→ Security Rules
```

**필수 Ingress Rule 확인:**
- Protocol: UDP (17)
- Source: 0.0.0.0/0
- Destination Port: 51820

**Terraform으로 확인:**
```bash
cd OCI-Wireguard/VPN-server
terraform state list | grep security_rule
terraform state show 'module.network.oci_core_network_security_group_security_rule.wireguard_inbound'
```

### 2. Security List 확인

```bash
# OCI Console
Networking → VCN → Security Lists → seclist-wireguard-vpn
→ Ingress Rules

# UDP 51820 허용되어 있는지 확인
```

### 3. 테스트: 모든 트래픽 임시 허용 (디버깅용)

**⚠️ 주의: 디버깅 후 반드시 제거할 것**

OCI Console에서 Security List에 임시 규칙 추가:
```
- Source CIDR: YOUR_IP/32
- IP Protocol: All Protocols
```

연결 테스트 후 이 규칙을 삭제하고 UDP 51820만 허용하세요.

---

## 🔑 5단계: Wireguard 서버 설정 확인

### 1. SSH로 VPN 서버 접속
```bash
ssh ubuntu@<VPN_PUBLIC_IP>
```

### 2. Wireguard 상태 확인
```bash
# Wireguard 인터페이스 상태
sudo wg show

# 정상 출력 예시:
# interface: wg0
#   public key: SERVER_PUBLIC_KEY
#   private key: (hidden)
#   listening port: 51820
#
# peer: CLIENT_PUBLIC_KEY
#   allowed ips: 192.168.255.2/32
```

**Wireguard가 안 떠있으면:**
```bash
# 수동 시작
sudo wg-quick up wg0

# 에러 확인
sudo journalctl -u wg-quick@wg0 -f
```

### 3. Wireguard 설정 파일 확인
```bash
sudo cat /etc/wireguard/wg0.conf
```

**확인 사항:**
```ini
[Interface]
PrivateKey = <서버 Private Key - 정상적으로 있어야 함>
Address = 10.255.255.10  # terraform.tfvars의 vm_private_ip
ListenPort = 51820

[Peer]
PublicKey = <클라이언트 Public Key>
AllowedIPs = 192.168.255.2/32  # 클라이언트 IP
```

**문제 있으면 수동 수정:**
```bash
sudo nano /etc/wireguard/wg0.conf

# 수정 후 재시작
sudo wg-quick down wg0
sudo wg-quick up wg0
```

### 4. IP Forwarding 확인
```bash
# IP Forwarding 활성화 확인
cat /proc/sys/net/ipv4/ip_forward
# 출력: 1 (활성화됨)

# sysctl 확인
sysctl net.ipv4.ip_forward
# 출력: net.ipv4.ip_forward = 1
```

**비활성화되어 있으면:**
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

### 5. iptables 규칙 확인
```bash
# FORWARD 체인 확인
sudo iptables -L FORWARD -v -n

# 다음 규칙이 있어야 함:
# ACCEPT all -- ens3 wg0
# ACCEPT all -- wg0 ens3
```

**규칙이 없으면:**
```bash
sudo iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o ens3 -j ACCEPT

# 저장
sudo netfilter-persistent save
```

### 6. 네트워크 인터페이스 확인
```bash
# wg0 인터페이스 확인
ip addr show wg0

# 정상 출력:
# wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420
#     inet 10.255.255.10/24 scope global wg0
```

---

## 💻 6단계: 클라이언트 설정 확인

### 1. 클라이언트 설정 파일 확인
```bash
# Linux/macOS
cat /etc/wireguard/wg0.conf
```

**필수 확인 사항:**
```ini
[Interface]
PrivateKey = <클라이언트 Private Key>
Address = 192.168.255.2/32  # 서버의 AllowedIPs와 일치

[Peer]
PublicKey = <서버 Public Key - terraform output에서 확인>
Endpoint = <VPN_PUBLIC_IP>:51820  # 반드시 Public IP
AllowedIPs = 192.168.0.0/16, 10.255.255.0/24
PersistentKeepalive = 25
```

### 2. 서버 Public Key 다시 확인
```bash
# VPN-server 디렉토리에서
cd OCI-Wireguard/VPN-server
terraform output -raw vpn_server_public_key

# 또는 서버에서
ssh ubuntu@<VPN_PUBLIC_IP> "sudo wg show wg0 public-key"
```

클라이언트 설정의 `PublicKey`가 위 출력과 **정확히 일치**하는지 확인!

### 3. 클라이언트 연결 시도
```bash
# Linux/macOS
sudo wg-quick up wg0

# 로그 확인
sudo wg show
```

**정상 출력:**
```
interface: wg0
  public key: CLIENT_PUBLIC_KEY
  private key: (hidden)
  listening port: 랜덤포트

peer: SERVER_PUBLIC_KEY
  endpoint: VPN_PUBLIC_IP:51820
  allowed ips: 192.168.0.0/16, 10.255.255.0/24
  latest handshake: X seconds ago  ← 중요! 최근 시간이어야 함
  transfer: XX B received, XX B sent
```

### 4. Handshake 확인

**Handshake가 발생하지 않으면 (latest handshake 없음):**

#### 클라이언트에서 tcpdump로 패킷 확인
```bash
# UDP 51820 패킷 확인
sudo tcpdump -i any -n udp port 51820 -v

# 연결 시도
sudo wg-quick up wg0

# 패킷이 나가는지 확인
# 출력: <CLIENT_IP>.랜덤포트 > <VPN_PUBLIC_IP>.51820: UDP
```

#### 서버에서 tcpdump로 패킷 수신 확인
```bash
# 서버에서
sudo tcpdump -i ens3 -n udp port 51820 -v

# 클라이언트에서 연결 시도 후 서버에 패킷이 들어오는지 확인
# 출력: <CLIENT_PUBLIC_IP>.랜덤포트 > <VPN_PRIVATE_IP>.51820: UDP
```

**패킷이 서버에 안 들어오면:**
- Security List/NSG 확인 (UDP 51820)
- 클라이언트의 Firewall 확인

**패킷이 들어오지만 Handshake 안되면:**
- 서버/클라이언트 Public Key 불일치
- Private Key 오류

---

## 🔄 7단계: Peer 설정 확인

### 1. 서버에 클라이언트 Peer가 등록되어 있는지 확인

**서버에서:**
```bash
sudo wg show wg0 peers
# 출력: CLIENT_PUBLIC_KEY
```

**Peer가 없으면:**
```bash
# terraform.tfvars에 추가
wg_peers = [
  {
    public_key  = "CLIENT_PUBLIC_KEY_HERE"
    endpoint    = ""
    allowed_ips = "192.168.255.2/32"
  }
]

# 재배포
terraform apply
```

### 2. AllowedIPs 확인

**서버에서:**
```bash
sudo wg show wg0 allowed-ips
# 출력: CLIENT_PUBLIC_KEY  192.168.255.2/32
```

클라이언트 설정의 `Address`와 서버의 `AllowedIPs`가 일치해야 합니다.

---

## 📊 8단계: 연결 테스트

### 1. VPN 터널 연결 후 Ping 테스트
```bash
# 클라이언트에서 VPN 서버 Private IP Ping
ping 10.255.255.10
```

**Ping 안되면:**

#### A. 클라이언트 라우팅 확인
```bash
# macOS/Linux
netstat -rn | grep 10.255.255

# 출력: 10.255.255.0/24 ... wg0
```

**라우팅이 없으면:**
```bash
# AllowedIPs에 VPN 서버 IP 포함 확인
# 클라이언트 wg0.conf:
AllowedIPs = 10.255.255.0/24, 192.168.0.0/16
```

#### B. 서버 방화벽 확인
```bash
# 서버에서
sudo iptables -L INPUT -v -n | grep wg0

# wg0 인터페이스에서 들어오는 패킷 허용 확인
```

### 2. Node 네트워크 접근 테스트 (Peering 확인)

**Node 네트워크를 배포한 경우:**
```bash
# 클라이언트에서 Node 네트워크 대역 Ping
ping 192.168.4.1
```

**Ping 안되면:**

#### A. LPG (Local Peering Gateway) 상태 확인
```
OCI Console → Networking → Virtual Cloud Networks
→ VPN VCN → Local Peering Gateways
→ 상태: PEERED 인지 확인

→ Node VCN → Local Peering Gateways
→ 상태: PEERED 인지 확인
```

#### B. Route Table 확인
```bash
cd OCI-Wireguard/Node-network
terraform state show 'module.network.oci_core_route_table.node'

# route_rules에 VPN client CIDR이 LPG를 가리키는지 확인
```

**OCI Console:**
```
VPN VCN → Route Tables → rt-wireguard-vpn
→ Route Rules
→ Destination: 192.168.4.0/24
→ Target: Local Peering Gateway

Node VCN → Route Tables → rt-node-network
→ Route Rules
→ Destination: 10.255.255.0/24 (또는 192.168.255.0/24)
→ Target: Local Peering Gateway
```

#### C. Node VCN Security List 확인
```
Node VCN → Security Lists
→ Ingress Rules
→ Source: 10.255.255.0/24
→ Protocol: All (또는 필요한 프로토콜)
```

---

## 🐛 9단계: 로그 수집 및 분석

### 서버 로그 수집
```bash
#!/bin/bash
# VPN 서버에서 실행

echo "=== Wireguard Status ==="
sudo wg show

echo -e "\n=== Wireguard Config ==="
sudo cat /etc/wireguard/wg0.conf

echo -e "\n=== IP Forwarding ==="
cat /proc/sys/net/ipv4/ip_forward

echo -e "\n=== Network Interfaces ==="
ip addr

echo -e "\n=== Route Table ==="
ip route

echo -e "\n=== iptables FORWARD ==="
sudo iptables -L FORWARD -v -n

echo -e "\n=== Wireguard Logs ==="
sudo journalctl -u wg-quick@wg0 -n 50 --no-pager

echo -e "\n=== System Logs (Wireguard) ==="
sudo dmesg | grep -i wireguard | tail -20

echo -e "\n=== Listening Ports ==="
sudo netstat -ulnp | grep wg
```

위 스크립트를 `debug.sh`로 저장 후 실행:
```bash
chmod +x debug.sh
./debug.sh > vpn-debug.log 2>&1
cat vpn-debug.log
```

### 클라이언트 로그 수집
```bash
#!/bin/bash

echo "=== Wireguard Status ==="
sudo wg show

echo -e "\n=== Wireguard Config ==="
sudo cat /etc/wireguard/wg0.conf

echo -e "\n=== Route Table ==="
netstat -rn | grep -E "wg0|Destination"

echo -e "\n=== DNS ==="
cat /etc/resolv.conf

echo -e "\n=== Ping VPN Server ==="
ping -c 3 10.255.255.10

echo -e "\n=== Wireguard Logs ==="
sudo journalctl -u wg-quick@wg0 -n 50 --no-pager
```

---

## 🔥 10단계: 일반적인 문제 및 해결책

### 문제 1: Handshake가 발생하지 않음

**증상:**
```bash
sudo wg show
# latest handshake: (없음)
```

**원인 및 해결:**

#### 1) Public Key 불일치
```bash
# 서버 Public Key 확인
ssh ubuntu@<VPN_IP> "sudo wg show wg0 public-key"

# 클라이언트 설정의 [Peer] PublicKey와 비교
cat /etc/wireguard/wg0.conf | grep PublicKey
```

#### 2) Endpoint IP 오류
```bash
# 클라이언트 설정에서 반드시 Public IP 사용
Endpoint = <VPN_PUBLIC_IP>:51820  # Private IP 아님!

# terraform output으로 확인
cd OCI-Wireguard/VPN-server
terraform output vpn_public_ip
```

#### 3) UDP 51820 차단됨
```bash
# 서버의 Security List 확인
# OCI Console → VCN → Security Lists → Ingress Rules
# UDP 51820 허용 확인

# 클라이언트 Firewall 확인 (macOS)
sudo pfctl -sr | grep 51820

# 클라이언트 Firewall 확인 (Linux)
sudo ufw status
sudo iptables -L OUTPUT -v -n | grep 51820
```

---

### 문제 2: Handshake는 되지만 Ping 안됨

**증상:**
```bash
sudo wg show
# latest handshake: 5 seconds ago  ← 있음
ping 10.255.255.10  # 안됨
```

**원인 및 해결:**

#### 1) IP Forwarding 비활성화
```bash
# 서버에서 확인
ssh ubuntu@<VPN_IP>
cat /proc/sys/net/ipv4/ip_forward
# 0이면 비활성화됨

# 활성화
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

#### 2) skip_source_dest_check 비활성화
```bash
# Terraform 확인
cd OCI-Wireguard/VPN-server
terraform state show 'module.wireguard.oci_core_instance.main' | grep skip_source_dest_check
# true 여야 함

# false이면 terraform.tfvars 재확인 후 재배포
```

#### 3) iptables FORWARD 규칙 누락
```bash
# 서버에서
sudo iptables -L FORWARD -v -n

# 규칙 추가
sudo iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o ens3 -j ACCEPT
sudo netfilter-persistent save
```

#### 4) 클라이언트 AllowedIPs 설정 오류
```bash
# 클라이언트 wg0.conf
[Peer]
AllowedIPs = 10.255.255.0/24, 192.168.0.0/16
#            ^^^^^^^^^^^^^^^^^ VPN 서버 IP 대역 포함해야 함
```

---

### 문제 3: VPN은 되지만 Node 네트워크 접근 안됨

**증상:**
```bash
ping 10.255.255.10  # OK
ping 192.168.4.X    # 안됨
```

**원인 및 해결:**

#### 1) Peering 상태 확인
```
OCI Console → VCN → Local Peering Gateways
상태: PEERED 확인
```

**PEERING이 아니면:**
```bash
cd OCI-Wireguard/Node-network
terraform destroy
terraform apply
```

#### 2) Route Table 누락
```bash
# Node VCN Route Table 확인
# VPN Client CIDR → LPG 경로 있어야 함

# VPN VCN Route Table 확인
# Node CIDR → LPG 경로 있어야 함
```

#### 3) Security List 확인
```
Node VCN → Security Lists → Ingress Rules
Source: 10.255.255.0/24 (VPN 서버)
또는 192.168.255.0/24 (VPN 클라이언트)
Protocol: All
```

---

### 문제 4: Terraform Apply 실패

**증상:**
```
Error: 400-InvalidParameter
```

**원인 및 해결:**

#### 1) Compartment 권한 부족
```bash
# OCI Console → Identity → Users → Your User
# Policies 확인:
# Allow group YourGroup to manage all-resources in compartment YourCompartment
```

#### 2) API Key 오류
```bash
# Fingerprint 확인
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c

# terraform.tfvars의 fingerprint와 비교
cat terraform.tfvars | grep fingerprint
```

#### 3) Image 없음
```bash
# Ubuntu 이미지 확인
oci compute image list \
  --compartment-id <COMPARTMENT_OCID> \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "22.04"
```

---

### 문제 5: Out of host capacity

**증상:**
```
Error: Out of host capacity
```

**해결:**

#### 1) 다른 Availability Domain 시도
```hcl
# wireguard/main.tf
availability_domain = data.oci_identity_availability_domains.ads.availability_domains[1].name
# 0 → 1 또는 2로 변경
```

#### 2) 다른 Shape 시도
```hcl
# Always Free 옵션:
vm_shape = "VM.Standard.E2.1.Micro"  # AMD
# 또는
vm_shape = "VM.Standard.A1.Flex"     # ARM (4 OCPU Free)
```

#### 3) 다른 Region 시도
```hcl
region = "ap-chuncheon-1"  # 서울 대신 춘천
# 또는
region = "ap-osaka-1"      # 오사카
```

---

## 📝 체크리스트: 모든 것을 확인했나요?

### Terraform 레벨
- [ ] `terraform apply` 성공
- [ ] `terraform output` 모든 값 출력됨
- [ ] `skip_source_dest_check = true` 확인

### 네트워크 레벨
- [ ] VPN Public IP Ping 됨
- [ ] SSH 접속 됨
- [ ] Security List에 UDP 51820 허용됨
- [ ] NSG에 UDP 51820 허용됨

### 서버 레벨
- [ ] `sudo wg show` 정상 출력
- [ ] Wireguard 서비스 실행 중
- [ ] IP Forwarding 활성화 (= 1)
- [ ] iptables FORWARD 규칙 존재
- [ ] `/etc/wireguard/wg0.conf` 정상
- [ ] 클라이언트 Peer 등록됨

### 클라이언트 레벨
- [ ] 서버 Public Key 정확함
- [ ] Endpoint = Public IP:51820
- [ ] AllowedIPs에 VPN 서버 대역 포함
- [ ] `sudo wg show` Handshake 발생
- [ ] VPN 서버 Private IP Ping 됨

### Peering 레벨 (Node 네트워크 사용 시)
- [ ] LPG 상태 = PEERED
- [ ] Route Table에 Peering 경로 있음
- [ ] Node VCN Security List에 VPN 허용

---

## 🆘 여전히 안되면?

### 로그 및 정보 수집
```bash
# 서버
ssh ubuntu@<VPN_IP>
sudo wg show > wg-status.txt
sudo cat /etc/wireguard/wg0.conf > wg-config.txt
sudo iptables -L -v -n > iptables.txt
sudo journalctl -u wg-quick@wg0 -n 100 > wg-logs.txt

# 클라이언트
sudo wg show > client-wg-status.txt
netstat -rn > route-table.txt
```

### OCI Support 티켓 생성
```
OCI Console → Support → Create Support Request
- 카테고리: Networking
- 문제: VPN connectivity issue
- 첨부: 위 로그 파일들
```

### Terraform 코드 검증
```bash
cd OCI-Wireguard/VPN-server
terraform validate
terraform plan
```

### 처음부터 다시 시작
```bash
# 완전 삭제
terraform destroy -auto-approve

# 재배포
terraform apply -auto-approve

# 서버 접속 후 로그 확인
ssh ubuntu@<새로운_PUBLIC_IP>
sudo journalctl -u wg-quick@wg0 -f
```

---

## 💡 빠른 진단 명령어 모음

### 원라인 진단 스크립트
```bash
# 서버에서 (SSH 접속 후)
echo "WG Status:" && sudo wg show && \
echo -e "\nIP Forward:" && cat /proc/sys/net/ipv4/ip_forward && \
echo -e "\nListening:" && sudo netstat -ulnp | grep 51820 && \
echo -e "\nForward Rules:" && sudo iptables -L FORWARD -v -n | grep -E "wg0|ens3"

# 클라이언트에서
echo "WG Status:" && sudo wg show && \
echo -e "\nPing VPN:" && ping -c 3 10.255.255.10 && \
echo -e "\nRoutes:" && netstat -rn | grep wg0
```

이 가이드를 단계별로 따라가면 대부분의 Wireguard VPN 연결 문제를 해결할 수 있습니다!
