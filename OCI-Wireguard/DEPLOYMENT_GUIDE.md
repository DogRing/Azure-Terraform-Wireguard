# OCI Wireguard VPN 배포 가이드

## 목차
1. [사전 준비](#사전-준비)
2. [VPN 서버 배포](#vpn-서버-배포)
3. [클라이언트 설정](#클라이언트-설정)
4. [Node 네트워크 배포](#node-네트워크-배포)
5. [검증 및 테스트](#검증-및-테스트)
6. [문제 해결](#문제-해결)

---

## 사전 준비

### 1. OCI 계정 및 권한 설정

#### OCI 계정 생성
1. https://www.oracle.com/cloud/free/ 접속
2. "Start for free" 클릭하여 계정 생성
3. Always Free Tier 활성화

#### Compartment 생성
1. OCI Console → Identity & Security → Compartments
2. "Create Compartment" 클릭
3. Name: `wireguard-compartment`
4. Compartment OCID 복사 (terraform.tfvars에 사용)

### 2. API Key 생성

#### CLI로 생성 (권장)
```bash
# 디렉토리 생성
mkdir -p ~/.oci

# Private Key 생성
openssl genrsa -out ~/.oci/oci_api_key.pem 2048

# Public Key 생성
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# 권한 설정
chmod 600 ~/.oci/oci_api_key.pem

# Fingerprint 확인
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
```

#### OCI Console에 Public Key 등록
1. OCI Console → User Settings (우측 상단 프로필)
2. "API Keys" → "Add API Key"
3. "Paste Public Key" 선택
4. `~/.oci/oci_api_key_public.pem` 내용 붙여넣기
5. "Add" 클릭
6. Fingerprint 확인 및 저장

### 3. OCI CLI 설치 (선택사항)

#### macOS
```bash
brew install oci-cli
```

#### Linux
```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

#### 설정
```bash
oci setup config
```

### 4. Terraform 설치

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 5. Wireguard 도구 설치

```bash
# macOS
brew install wireguard-tools

# Ubuntu/Debian
sudo apt update
sudo apt install wireguard

# RHEL/CentOS
sudo yum install wireguard-tools
```

---

## VPN 서버 배포

### 1. 디렉토리 이동
```bash
cd OCI-Wireguard/VPN-server
```

### 2. terraform.tfvars 생성

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 편집:
```hcl
# OCI 인증 정보 (위에서 생성한 값들)
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaa..."
user_ocid        = "ocid1.user.oc1..aaaaa..."
fingerprint      = "aa:bb:cc:dd:..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "ap-seoul-1"

# Compartment
compartment_id = "ocid1.compartment.oc1..aaaaa..."

# 프로젝트 이름
project_name = "wireguard-vpn"

# 네트워크 설정
vcn_cidr      = "10.255.255.0/24"
subnet_cidr   = "10.255.255.0/24"
vm_private_ip = "10.255.255.10"
vpn_port      = "51820"

# SSH 접근 제한 (보안상 권장)
enable_ssh = ["YOUR_PUBLIC_IP/32"]

# VM 설정 (Always Free)
vm_shape               = "VM.Standard.E2.1.Micro"
boot_volume_size_in_gbs = 50
ssh_public_key_path    = "~/.ssh/id_rsa.pub"
```

### 3. Terraform 초기화 및 배포

```bash
# Terraform 초기화
terraform init

# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

배포가 완료되면 출력 확인:
```bash
terraform output
```

출력 예시:
```
vpn_public_ip = "132.145.XXX.XXX"
vpn_private_ip = "10.255.255.10"
vpn_server_public_key = <sensitive>
```

### 4. 서버 Public Key 확인

```bash
terraform output -json vpn_server_public_key | jq -r
```

또는 SSH로 서버 접속 후:
```bash
ssh ubuntu@<VPN_PUBLIC_IP>
sudo wg show
```

---

## 클라이언트 설정

### 1. 클라이언트 키 생성

```bash
# Private Key 생성
wg genkey | tee client_private.key | wg pubkey > client_public.key

# 생성된 키 확인
cat client_private.key
cat client_public.key
```

### 2. 서버에 클라이언트 Peer 추가

`terraform.tfvars`에 wg_peers 추가:
```hcl
wg_peers = [
  {
    public_key  = "CLIENT_PUBLIC_KEY_FROM_ABOVE"
    endpoint    = ""  # Road warrior client는 비워둠
    allowed_ips = "192.168.255.2/32"
  }
]
```

서버 재배포:
```bash
terraform apply
```

### 3. 클라이언트 설정 파일 생성

#### Linux/macOS

`/etc/wireguard/wg0.conf` 생성:
```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 192.168.255.2/32
DNS = 8.8.8.8

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 192.168.0.0/16, 10.255.255.0/24
PersistentKeepalive = 25
```

연결:
```bash
sudo wg-quick up wg0

# 자동 시작 설정
sudo systemctl enable wg-quick@wg0
```

#### Windows

1. Wireguard 다운로드: https://www.wireguard.com/install/
2. "Add Tunnel" → "Add empty tunnel..."
3. 위 설정 내용 붙여넣기
4. "Activate" 클릭

#### iOS/Android

1. App Store/Play Store에서 "Wireguard" 설치
2. QR 코드 생성:
   ```bash
   qrencode -t ansiutf8 < /etc/wireguard/wg0.conf
   ```
3. 앱에서 QR 코드 스캔

### 4. 연결 확인

```bash
# VPN 인터페이스 확인
sudo wg show

# VPN 서버 Ping
ping 10.255.255.10

# 연결 상태 확인
sudo wg show wg0
```

---

## Node 네트워크 배포

Node 네트워크는 VPN을 통해 접근할 수 있는 내부 네트워크입니다.

### 1. VPN 서버 정보 확인

VPN-server 디렉토리에서:
```bash
terraform output -json vpn_config
```

출력된 값을 복사합니다.

### 2. Node 네트워크 배포

```bash
cd ../Node-network
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 편집:
```hcl
# OCI 인증 정보 (VPN 서버와 동일)
tenancy_ocid     = "..."
user_ocid        = "..."
fingerprint      = "..."
private_key_path = "~/.oci/oci_api_key.pem"
region           = "ap-seoul-1"
compartment_id   = "..."

# 프로젝트 이름
project_name = "node-network"

# 네트워크 설정
vcn_cidr    = "192.168.4.0/24"
subnet_cidr = "192.168.4.0/24"

# VPN 설정 (위에서 복사한 값)
vpn_config = {
  compartment_id = "ocid1.compartment..."
  vcn_id         = "ocid1.vcn..."
  subnet_id      = "ocid1.subnet..."
  private_ip     = "10.255.255.10"
}

# 라우팅 설정
route_cidrs = [
  "192.168.255.128/25",  # VPN clients
  "192.168.0.0/24",
  "192.168.1.0/24",
  "192.168.3.0/24"
]

vpn_client_cidr = "10.255.255.0/24"
```

배포:
```bash
terraform init
terraform plan
terraform apply
```

### 3. Peering 확인

OCI Console에서 확인:
1. Networking → Virtual Cloud Networks
2. VPN VCN과 Node VCN 선택
3. "Local Peering Gateways" 메뉴에서 Peering 상태 확인 (PEERED)

---

## 검증 및 테스트

### 1. VPN 연결 테스트

```bash
# 클라이언트에서 VPN 서버 Ping
ping 10.255.255.10

# Wireguard 상태 확인
sudo wg show
```

### 2. Node 네트워크 접근 테스트

Node 네트워크에 테스트 VM 생성 후:
```bash
# 클라이언트에서 Node VM Ping
ping 192.168.4.X
```

### 3. 라우팅 확인

클라이언트에서:
```bash
# 라우팅 테이블 확인 (macOS/Linux)
netstat -rn | grep 192.168

# Windows
route print
```

### 4. 로그 확인

VPN 서버에서:
```bash
# Wireguard 상태
sudo wg show

# 시스템 로그
sudo journalctl -u wg-quick@wg0 -f

# iptables 규칙 확인
sudo iptables -L -v -n
```

---

## 문제 해결

### 문제 1: SSH 접속 안됨

**증상**: VPN 서버에 SSH로 접속 불가

**해결**:
1. Security List 확인:
   ```bash
   # OCI Console → VCN → Security Lists → Ingress Rules
   # TCP 22번 포트가 열려있는지 확인
   ```

2. `terraform.tfvars`에 SSH 허용:
   ```hcl
   enable_ssh = ["YOUR_IP/32"]
   terraform apply
   ```

3. SSH Key 확인:
   ```bash
   ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>
   ```

### 문제 2: Wireguard 연결 안됨

**증상**: VPN 클라이언트가 서버에 연결되지 않음

**해결**:
1. UDP 51820 포트 오픈 확인:
   ```bash
   # 서버에서
   sudo netstat -ulnp | grep 51820
   ```

2. 클라이언트 설정 확인:
   - Server Public Key 정확한지 확인
   - Endpoint IP:Port 정확한지 확인

3. 서버에서 Peer 추가 확인:
   ```bash
   sudo wg show
   # 클라이언트 Public Key가 보여야 함
   ```

4. Handshake 확인:
   ```bash
   # 서버에서
   sudo wg show wg0
   # "latest handshake" 시간이 최근이어야 함
   ```

### 문제 3: Node 네트워크 Ping 안됨

**증상**: VPN은 연결되지만 Node 네트워크 접근 불가

**해결**:
1. Peering 상태 확인:
   ```bash
   # OCI Console에서 LPG 상태가 "PEERED"인지 확인
   ```

2. Route Table 확인:
   ```bash
   # OCI Console → VCN → Route Tables
   # Node CIDR로 가는 Route가 LPG를 가리키는지 확인
   ```

3. Security List 확인:
   ```bash
   # Node VCN Security List에서 VPN CIDR 허용 확인
   ```

4. IP Forwarding 확인:
   ```bash
   # VPN 서버에서
   cat /proc/sys/net/ipv4/ip_forward
   # 1이어야 함
   ```

### 문제 4: Terraform Apply 실패

**증상**: `terraform apply` 실행 시 오류

**해결**:
1. OCI 인증 정보 확인:
   ```bash
   # API Key 권한 확인
   ls -la ~/.oci/oci_api_key.pem
   # 600 권한이어야 함

   # Fingerprint 확인
   openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
   ```

2. Compartment 권한 확인:
   - OCI Console에서 Compartment에 대한 권한 확인
   - VCN, Compute 리소스 생성 권한 필요

3. Quota 확인:
   ```bash
   # OCI Console → Governance → Limits, Quotas and Usage
   # Compute, VCN quota 확인
   ```

### 문제 5: Always Free 리소스 제한

**증상**: VM 생성 시 "Out of host capacity" 오류

**해결**:
1. 다른 Availability Domain 시도:
   ```hcl
   # wireguard/main.tf에서
   availability_domain = data.oci_identity_availability_domains.ads.availability_domains[1].name
   # 또는 [2]
   ```

2. 다른 리전 시도:
   ```hcl
   region = "ap-chuncheon-1"  # 또는 다른 리전
   ```

3. Shape 변경:
   ```hcl
   vm_shape = "VM.Standard.A1.Flex"  # ARM 기반 (Always Free 4 OCPU)
   ```

---

## 보안 권장사항

1. **SSH 접근 제한**:
   ```hcl
   enable_ssh = ["YOUR_IP/32"]  # 특정 IP만 허용
   ```

2. **Private Key 관리**:
   ```bash
   # Private Key 파일 권한 설정
   chmod 600 ~/.oci/oci_api_key.pem
   chmod 600 client_private.key
   ```

3. **Wireguard Key 주기적 갱신**:
   ```bash
   # 3-6개월마다 키 재생성
   wg genkey | tee new_private.key | wg pubkey > new_public.key
   ```

4. **Terraform State 보안**:
   ```bash
   # S3 또는 OCI Object Storage에 State 저장 권장
   # Remote backend 설정
   ```

5. **NSG 사용 권장**:
   - Security List보다 NSG가 더 세밀한 제어 가능

---

## 비용 최적화

### Always Free Tier 활용

- **Compute**: VM.Standard.E2.1.Micro 2개 무료
- **Block Volume**: 200GB 무료
- **VCN**: 무제한
- **Outbound Transfer**: 10TB/월 무료

### 비용 모니터링

```bash
# OCI Console → Cost Management → Cost Analysis
# 일별/월별 비용 추적
```

### 리소스 정리

사용하지 않는 리소스 삭제:
```bash
terraform destroy
```

---

## 참고 자료

- [OCI Documentation](https://docs.oracle.com/en-us/iaas/)
- [Terraform OCI Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [Wireguard Documentation](https://www.wireguard.com/)
- [OCI Always Free](https://www.oracle.com/cloud/free/)
