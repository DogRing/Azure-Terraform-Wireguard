# Remote Networks 설정 가이드

VPN을 통해 원격 네트워크(예: 192.168.0.0/24)에 접근하도록 라우팅을 설정하는 방법입니다.

## 개요

VPN 클라이언트가 VPN 서버를 통해 원격 네트워크에 접근할 수 있도록 Route Rule을 추가합니다.

### 네트워크 구조

```
┌──────────────────────────────────────────────────────┐
│ VPN Client                                           │
│ IP: 192.168.255.2                                    │
│                                                       │
│ Local Network: 192.168.0.0/24 ───────┐              │
│ (클라이언트 뒤의 네트워크)                │              │
└──────────────────────────────────────┼───────────────┘
                                       │
                          Wireguard Tunnel
                                       │
                                       ↓
┌──────────────────────────────────────────────────────┐
│ VPN VCN (10.255.0.0/16)                              │
│                                                       │
│  ┌─────────────────────────────────────────────┐    │
│  │ VPN Subnet (10.255.255.0/24)                │    │
│  │                                              │    │
│  │  ┌────────────────────────────────────┐    │    │
│  │  │ VPN Server (10.255.255.10)         │    │    │
│  │  │ - IP Forwarding: Enabled           │    │    │
│  │  │ - Routes 192.168.0.0/24 traffic    │    │    │
│  │  └────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────┘    │
│                       │                              │
│                Route Rule:                           │
│           192.168.0.0/24 → 10.255.255.10            │
│                       │                              │
│  ┌─────────────────────────────────────────────┐    │
│  │ Node Subnet (10.255.1.0/24)                 │    │
│  │                                              │    │
│  │  ┌────────────────────────────────────┐    │    │
│  │  │ Node Resources                     │    │    │
│  │  │ Can access 192.168.0.0/24          │    │    │
│  │  └────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

## 사용 사례

### 사례 1: VPN 클라이언트 뒤의 로컬 네트워크
VPN 클라이언트가 사무실에 있고, 사무실 네트워크(192.168.0.0/24)를 OCI 리소스에서 접근하고 싶은 경우

### 사례 2: 사이트 간 VPN (Site-to-Site VPN)
원격 사무실의 전체 네트워크를 VPN을 통해 연결

### 사례 3: 다중 원격 네트워크
여러 지점의 네트워크를 모두 VPN을 통해 상호 연결

## 설정 방법

### 1. terraform.tfvars 편집

```hcl
# Remote Networks (accessible through VPN)
remote_networks = [
  "192.168.0.0/24",    # Remote office 1
  "192.168.1.0/24",    # Remote office 2
  "192.168.3.0/24",    # Remote office 3
]
```

### 2. Terraform 적용

```bash
cd OCI-Wireguard/VPN-server
terraform plan
terraform apply
```

### 3. Route Rule 확인

**OCI Console:**
```
Networking → VCN → Route Tables → rt-wireguard-vpn
→ Route Rules

출력:
- Destination: 0.0.0.0/0 → Internet Gateway
- Destination: 192.168.0.0/24 → Private IP (10.255.255.10)
- Destination: 192.168.1.0/24 → Private IP (10.255.255.10)
```

**Terraform:**
```bash
terraform state show 'module.network.oci_core_route_table.main'
```

## VPN 클라이언트 설정

### Wireguard 설정 파일 수정

클라이언트가 원격 네트워크를 Advertise하도록 설정해야 합니다.

**Linux/macOS: `/etc/wireguard/wg0.conf`**
```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 192.168.255.2/32

# Post-up: 로컬 네트워크를 VPN을 통해 광고
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostUp = ip route add 10.255.0.0/16 dev wg0

# Post-down: 정리
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip route del 10.255.0.0/16 dev wg0

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 10.255.0.0/16  # VPN VCN 전체
PersistentKeepalive = 25
```

### 클라이언트 라우팅 활성화

**Linux:**
```bash
# IP Forwarding 활성화
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# iptables NAT 설정
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save
```

**macOS:**
```bash
# pfctl 설정
sudo sysctl -w net.inet.ip.forwarding=1

# NAT 규칙 추가 (/etc/pf.conf)
nat on en0 from 192.168.0.0/24 to any -> (en0)
sudo pfctl -f /etc/pf.conf -e
```

## VPN 서버 Wireguard 설정 업데이트

서버에서 클라이언트의 로컬 네트워크를 인식하도록 AllowedIPs 업데이트:

**terraform.tfvars:**
```hcl
wg_peers = [
  {
    public_key  = "CLIENT_PUBLIC_KEY"
    endpoint    = ""
    allowed_ips = "192.168.255.2/32, 192.168.0.0/24"  # 클라이언트 IP + 로컬 네트워크
  }
]
```

재배포:
```bash
terraform apply
```

## 테스트

### 1. VPN 연결 확인
```bash
# 클라이언트에서
sudo wg show
# latest handshake가 최근이어야 함
```

### 2. Node 서브넷에서 원격 네트워크 Ping
```bash
# Node VM (10.255.1.10)에서
ping 192.168.0.1  # 클라이언트 로컬 네트워크의 장비

# 성공하면 라우팅이 정상
```

### 3. 패킷 경로 추적
```bash
# Node VM에서
traceroute 192.168.0.1

# 출력 예시:
# 1  10.255.255.10 (VPN 서버)
# 2  192.168.0.1 (원격 네트워크)
```

### 4. VPN 서버에서 트래픽 확인
```bash
# VPN 서버에서
ssh ubuntu@<VPN_IP>

# Wireguard 통계
sudo wg show wg0

# 패킷 캡처
sudo tcpdump -i wg0 -n host 192.168.0.1
```

## 문제 해결

### 문제 1: 원격 네트워크 Ping 안됨

**확인 사항:**

1. **Route Rule 존재 확인:**
   ```bash
   terraform state show 'module.network.oci_core_route_table.main'
   ```

2. **VPN 서버 IP Forwarding:**
   ```bash
   ssh ubuntu@<VPN_IP>
   cat /proc/sys/net/ipv4/ip_forward
   # 출력: 1
   ```

3. **VPN 서버 iptables:**
   ```bash
   sudo iptables -L FORWARD -v -n
   # wg0 ↔ ens3 양방향 ACCEPT 확인
   ```

4. **클라이언트 AllowedIPs:**
   ```bash
   # 서버의 /etc/wireguard/wg0.conf
   sudo cat /etc/wireguard/wg0.conf
   # AllowedIPs에 192.168.0.0/24 포함되어야 함
   ```

### 문제 2: 단방향 통신만 됨

**증상:** Node → 원격 네트워크는 되지만, 역방향 안됨

**해결:**

클라이언트에서 NAT 설정:
```bash
sudo iptables -t nat -A POSTROUTING -s 10.255.0.0/16 -o eth0 -j MASQUERADE
```

### 문제 3: 특정 네트워크만 안됨

**확인:**

1. **terraform.tfvars의 remote_networks:**
   ```hcl
   remote_networks = [
     "192.168.0.0/24",  # 이 네트워크가 포함되어 있는지
   ]
   ```

2. **서버 Peer AllowedIPs:**
   ```hcl
   wg_peers = [
     {
       allowed_ips = "192.168.255.2/32, 192.168.0.0/24"
     }
   ]
   ```

## 고급 설정

### 여러 클라이언트가 서로 다른 네트워크를 광고하는 경우

**클라이언트 1 (사무실 A):**
```hcl
wg_peers = [
  {
    public_key  = "CLIENT_1_PUBLIC_KEY"
    allowed_ips = "192.168.255.2/32, 192.168.0.0/24"
  }
]
```

**클라이언트 2 (사무실 B):**
```hcl
wg_peers = [
  {
    public_key  = "CLIENT_2_PUBLIC_KEY"
    allowed_ips = "192.168.255.3/32, 192.168.1.0/24"
  }
]
```

**remote_networks:**
```hcl
remote_networks = [
  "192.168.0.0/24",  # 사무실 A
  "192.168.1.0/24",  # 사무실 B
]
```

이제 **사무실 A ↔ 사무실 B**도 VPN을 통해 통신 가능!

## 참고 자료

- [Wireguard Site-to-Site VPN](https://www.wireguard.com/quickstart/#site-to-site-vpn)
- [OCI Route Tables](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingroutetables.htm)
- [Linux IP Forwarding](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
