# Oracle Cloud Infrastructure (OCI) Wireguard VPN

Azure에서 OCI로 마이그레이션한 Wireguard VPN 인프라 코드입니다.

## 디렉토리 구조

```
OCI-Wireguard/
├── VPN-server/          # Wireguard VPN 서버
│   ├── network/         # VCN, Subnet, Security 설정
│   └── wireguard/       # Compute Instance 및 Wireguard 설정
├── Node-network/        # Node용 서브넷 (VPN VCN 내)
│   └── network/         # Subnet, Route, Security 설정
├── scripts/             # 디버깅 스크립트
│   ├── debug-server.sh  # 서버 자동 진단
│   └── debug-client.sh  # 클라이언트 자동 진단
├── DEPLOYMENT_GUIDE.md  # 상세 배포 가이드
├── TROUBLESHOOTING.md   # 문제 해결 가이드
└── COMPARISON_SUMMARY.md # Azure vs OCI 비교
```

## 네트워크 구조

```
VPN VCN (10.255.0.0/16)
├── VPN Subnet (10.255.255.0/24)
│   └── Wireguard VPN Server (10.255.255.10)
│
└── Node Subnet (10.255.1.0/24)  ← 같은 VCN 내
    └── Node Resources

VPN 클라이언트 (192.168.255.0/24)
└── Wireguard 터널 → VPN 서버 → Node 서브넷
```

**특징:**
- ✅ **단일 VCN**: LPG (Peering) 불필요
- ✅ **간단한 라우팅**: 같은 VCN 내 서브넷 간 통신
- ✅ **비용 절감**: Peering Gateway 비용 없음
- ✅ **관리 용이**: 하나의 VCN만 관리
```

## 사전 준비

### 1. OCI 계정 설정
```bash
# OCI CLI 설치
brew install oci-cli  # macOS
# 또는
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"

# OCI 설정
oci setup config
```

### 2. API Key 생성
1. OCI Console → User Settings → API Keys
2. "Add API Key" 클릭
3. Private Key 다운로드 및 저장
4. Fingerprint 확인

### 3. Terraform 변수 설정
`terraform.tfvars` 파일 생성:

```hcl
# OCI Authentication
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaa..."
fingerprint      = "aa:bb:cc:dd:ee:..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "ap-seoul-1"

# Compartment
compartment_id = "ocid1.compartment.oc1..aaaaa..."

# Network (large VCN for multiple subnets)
vcn_cidr = "10.255.0.0/16"
vpn_subnet_cidr = "10.255.255.0/24"

# Wireguard
vpn_port = "51820"
vm_private_ip = "10.255.255.10"

# SSH Key
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

## 배포 순서

### 1. VPN 서버 배포
```bash
cd VPN-server
terraform init
terraform plan
terraform apply
```

### 2. 출력 확인
```bash
terraform output
```

다음 정보를 확인:
- VPN 서버 Public IP
- VPN 서버 Private IP
- Wireguard Public Key

### 3. Node 서브넷 배포 (선택사항)

VPN을 통해 접근할 리소스를 위한 서브넷을 추가합니다.

```bash
cd ../Node-network
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 편집
# vpn_vcn_id = VPN-server의 terraform output vcn_id
nano terraform.tfvars

terraform init
terraform plan
terraform apply
```

**주의**: Node-network는 VPN VCN 내에 서브넷만 추가하므로, VPN-server가 먼저 배포되어야 합니다.

## Wireguard 클라이언트 설정

### Linux/macOS
```bash
sudo apt install wireguard  # Ubuntu/Debian
brew install wireguard-tools  # macOS
```

클라이언트 설정 파일 (`/etc/wireguard/wg0.conf`):
```ini
[Interface]
PrivateKey = <클라이언트 Private Key>
Address = 192.168.255.2/32

[Peer]
PublicKey = <서버 Public Key - terraform output에서 확인>
Endpoint = <서버 Public IP>:51820
AllowedIPs = 192.168.0.0/16
PersistentKeepalive = 25
```

연결:
```bash
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

## Always Free Tier

OCI Always Free 리소스 활용:
- **VM.Standard.E2.1.Micro**: 2개 무료 (AMD)
  - 1/8 OCPU
  - 1GB RAM
- **Block Volume**: 200GB 무료
- **Outbound Data Transfer**: 10TB/월 무료
- **VCN**: 무제한

## 주요 차이점 (Azure vs OCI)

| 항목 | Azure | OCI |
|------|-------|-----|
| **리소스 그룹** | Resource Group | Compartment |
| **가상 네트워크** | Virtual Network | Virtual Cloud Network |
| **보안 그룹** | NSG | NSG or Security List |
| **Public IP** | Public IP 리소스 | VNIC에 직접 할당 |
| **IP Forwarding** | `enable_ip_forwarding` | `skip_source_dest_check` |
| **네트워크 구조** | VNet Peering 필요 | 같은 VCN 내 서브넷 |
| **VM** | Virtual Machine | Compute Instance |
| **VM 크기** | Size (Standard_B1s) | Shape (VM.Standard.E4.Flex) |

상세 내용은 `../AZURE_TO_OCI_MIGRATION.md` 참조

## 문제 해결

### 1. SSH 접속 안됨
- Security List/NSG에서 22번 포트 확인
- Public IP 할당 확인
- SSH Key 확인

### 2. Wireguard 연결 안됨
- UDP 51820 포트 오픈 확인
- `skip_source_dest_check = true` 확인
- Route Table 설정 확인

### 3. Node 서브넷 통신 안됨
- Route Table 확인 (VPN 클라이언트 → VPN 서버 IP)
- Security List 확인 (VPN 클라이언트 CIDR 허용)
- VPN 서버 IP Forwarding 확인

## 참고 자료

- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [OCI 네트워킹 개요](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/overview.htm)
- [Wireguard 공식 문서](https://www.wireguard.com/)
- [OCI Always Free](https://www.oracle.com/cloud/free/)
