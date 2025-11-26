# Node Network in VPN VCN

VPN VCN 내에 Node용 서브넷을 생성하는 모듈입니다.

## 개요

이 모듈은 **별도의 VCN을 생성하지 않고** VPN-server에서 생성한 VPN VCN 내에 새로운 서브넷을 추가합니다.

### 네트워크 구조

```
VPN VCN (10.255.0.0/16)
├── VPN Subnet (10.255.255.0/24)
│   └── Wireguard VPN Server (10.255.255.10)
│
└── Node Subnet (10.255.1.0/24)  ← 이 모듈이 생성
    └── Node Resources (VM, 컨테이너 등)
```

### 장점

1. **간단한 구조**: LPG (Local Peering Gateway) 불필요
2. **자동 라우팅**: 같은 VCN 내이므로 서브넷 간 기본 통신 가능
3. **비용 절감**: Peering Gateway 비용 없음
4. **관리 용이**: 하나의 VCN만 관리

## 사전 준비

### 1. VPN-server 배포 완료
먼저 VPN-server를 배포해야 합니다.

```bash
cd ../VPN-server
terraform apply
```

### 2. VPN VCN ID 확인
```bash
cd ../VPN-server
terraform output vcn_id
```

출력:
```
ocid1.vcn.oc1.ap-seoul-1.aaaaaaaxxxxxxx
```

이 값을 복사합니다.

## 배포 방법

### 1. terraform.tfvars 생성

```bash
cd OCI-Wireguard/Node-network
cp terraform.tfvars.example terraform.tfvars
```

### 2. terraform.tfvars 편집

```hcl
# OCI 인증 정보 (VPN-server와 동일)
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaa..."
fingerprint      = "aa:bb:cc:dd:..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "ap-seoul-1"
compartment_id   = "ocid1.compartment.oc1..aaaaa..."

# 프로젝트 이름
project_name = "node-network"

# VPN VCN ID (VPN-server output에서 복사)
vpn_vcn_id = "ocid1.vcn.oc1.ap-seoul-1.aaaaa..."

# Node 서브넷 CIDR (VPN VCN 10.255.0.0/16 내에서 선택)
node_subnet_cidr = "10.255.1.0/24"

# VPN 서버 정보
vpn_server_private_ip = "10.255.255.10"
vpn_subnet_cidr       = "10.255.255.0/24"

# VPN 클라이언트 CIDR
vpn_client_cidr = "192.168.255.0/24"

# VPN을 통해 라우팅할 CIDR (VPN 클라이언트가 Node에 접근하도록)
route_cidrs = [
  "192.168.255.0/24",  # VPN 클라이언트
]
```

### 3. Terraform 배포

```bash
terraform init
terraform plan
terraform apply
```

## 라우팅 설정

### VPN 클라이언트 → Node 서브넷

VPN 클라이언트에서 Node 서브넷(10.255.1.0/24)으로 가는 트래픽은:
1. Wireguard 터널을 통해 VPN 서버로
2. VPN 서버에서 **같은 VCN 내 다른 서브넷**으로 포워딩
3. Node 서브넷 도달

**Route Table 자동 설정:**
- Destination: 192.168.255.0/24 (VPN 클라이언트)
- Target: VPN 서버 Private IP (10.255.255.10)

### Node 서브넷 → VPN 클라이언트

Node 서브넷에서 VPN 클라이언트(192.168.255.0/24)로 가는 트래픽은:
1. Route Table에 의해 VPN 서버 Private IP로
2. VPN 서버에서 Wireguard 터널을 통해 클라이언트로

## Security 설정

### Security List

Node 서브넷의 Security List:
- **Ingress**:
  - VPN 서버 서브넷 (10.255.255.0/24): 모든 프로토콜 허용
  - VPN 클라이언트 (192.168.255.0/24): 모든 프로토콜 허용
  - Node 서브넷 내부 (10.255.1.0/24): 모든 프로토콜 허용
  - ICMP (Ping): 모든 소스 허용

- **Egress**:
  - 모든 대상: 모든 프로토콜 허용

### Network Security Group (NSG)

추가적인 세밀한 제어를 위해 NSG 제공:
- VPN 서버/클라이언트 접근 제어
- 특정 포트/프로토콜만 허용 가능
- 리소스별 적용 가능

## 테스트

### 1. Node 서브넷에 테스트 VM 생성

```hcl
# test-vm.tf
resource "oci_core_instance" "test" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E2.1.Micro"
  display_name        = "test-node-vm"

  create_vnic_details {
    subnet_id    = module.network.subnet_id  # Node 서브넷
    assign_public_ip = false  # Private subnet
  }

  # ... 생략
}
```

### 2. VPN 클라이언트에서 Ping 테스트

```bash
# VPN 연결
sudo wg-quick up wg0

# Node 서브넷 게이트웨이 Ping
ping 10.255.1.1

# Node VM Ping (VM IP가 10.255.1.10이라고 가정)
ping 10.255.1.10
```

### 3. Node VM에서 VPN 서버 Ping

```bash
# Node VM에 SSH 접속 (bastion 또는 VPN 통해)
ping 10.255.255.10  # VPN 서버
```

## 추가 서브넷 생성

더 많은 서브넷이 필요한 경우:

```hcl
# 다른 Node-network 디렉토리 복사
cp -r Node-network Node-network-2

# terraform.tfvars 수정
node_subnet_cidr = "10.255.2.0/24"  # 다른 CIDR
project_name = "node-network-2"
```

**사용 가능한 서브넷 CIDR** (VPN VCN 10.255.0.0/16 내):
- 10.255.1.0/24
- 10.255.2.0/24
- 10.255.3.0/24
- ...
- 10.255.254.0/24
- (10.255.255.0/24는 VPN 서버가 사용 중)

## 문제 해결

### 문제 1: VPN 클라이언트에서 Node Ping 안됨

**확인:**
```bash
# 1. VPN 서버 IP Forwarding 확인
ssh ubuntu@<VPN_IP>
cat /proc/sys/net/ipv4/ip_forward
# 출력: 1

# 2. VPN 서버 iptables 확인
sudo iptables -L FORWARD -v -n
```

**해결:**
```bash
# IP Forwarding 활성화
sudo sysctl -w net.ipv4.ip_forward=1

# iptables 규칙 추가 (필요 시)
sudo iptables -A FORWARD -i wg0 -o ens3 -j ACCEPT
sudo iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
```

### 문제 2: Route가 작동하지 않음

**확인:**
```bash
# OCI Console
Networking → VCN → Route Tables → rt-node-network
→ Route Rules 확인

# Terraform
terraform state show 'module.network.oci_core_route_table.node'
```

**해결:**
```bash
terraform apply -refresh-only
```

### 문제 3: Security List 차단

**확인:**
```bash
# OCI Console
Networking → VCN → Security Lists → seclist-node-network
→ Ingress Rules 확인
```

## 참고

- VPN VCN CIDR: 10.255.0.0/16 (65,536 IP)
- VPN Subnet: 10.255.255.0/24 (256 IP)
- Node Subnet: 10.255.1.0/24 (256 IP)
- 사용 가능: 10.255.0.0 ~ 10.255.254.255 (254개 /24 서브넷)

## 관련 문서

- `../VPN-server/README.md`: VPN 서버 배포 가이드
- `../TROUBLESHOOTING.md`: 디버깅 가이드
- `../DEPLOYMENT_GUIDE.md`: 전체 배포 가이드
