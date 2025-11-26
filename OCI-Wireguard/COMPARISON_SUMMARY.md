# Azure vs Oracle Cloud Infrastructure 비교 요약

## 개요
Azure 기반 Wireguard VPN 인프라를 Oracle Cloud Infrastructure (OCI)로 마이그레이션한 내용을 요약합니다.

---

## 주요 리소스 비교표

| 카테고리 | Azure 리소스 | OCI 리소스 | 주요 차이점 |
|---------|-------------|-----------|-----------|
| **조직/관리** | Resource Group | Compartment | OCI는 계층 구조 지원 |
| **네트워크** | Virtual Network (VNet) | Virtual Cloud Network (VCN) | 기본 개념 유사 |
| **서브넷** | Subnet | Subnet | OCI는 Regional/AD 선택 가능 |
| **보안 그룹** | Network Security Group | NSG or Security List | OCI는 두 가지 옵션 제공 |
| **공인 IP** | Public IP (리소스) | VNIC에 직접 할당 | OCI는 Reserved/Ephemeral 구분 |
| **네트워크 인터페이스** | NIC | VNIC | OCI는 Instance와 함께 정의 |
| **네트워크 피어링** | VNet Peering | Local Peering Gateway (LPG) | OCI는 리전 간에는 DRG 필요 |
| **라우팅** | Route Table | Route Table | OCI는 Route Rule을 내부에 정의 |
| **가상 머신** | Virtual Machine | Compute Instance | OCI는 Shape 개념 사용 |
| **VM 크기** | Size (예: Standard_B1s) | Shape (예: VM.Standard.E4.Flex) | OCI Flex Shape은 OCPU/메모리 조정 가능 |
| **스토리지** | Storage Account | Object Storage / File Storage | OCI는 용도별로 분리 |
| **인증** | Service Principal | API Key (Private Key + Fingerprint) | OCI는 RSA 키 기반 |

---

## Terraform 코드 비교

### Provider 설정

**Azure:**
```hcl
provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  features {}
}
```

**OCI:**
```hcl
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
```

---

### 네트워크 생성

**Azure:**
```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}
```

**OCI:**
```hcl
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr_block]
  display_name   = "vcn-${var.project_name}"
  dns_label      = var.dns_label  # OCI 추가 필수 항목
}
```

**주요 차이:**
- OCI는 `dns_label` 필수
- OCI는 Resource Group 대신 `compartment_id` 사용
- OCI는 `location` 대신 provider에서 `region` 지정

---

### 서브넷 생성

**Azure:**
```hcl
resource "azurerm_subnet" "main" {
  name                 = "subnet-${var.project_name}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefix]
}
```

**OCI:**
```hcl
resource "oci_core_subnet" "main" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.subnet_cidr
  display_name               = "subnet-${var.project_name}"
  dns_label                  = "subnet${var.project_name}"
  prohibit_public_ip_on_vnic = false  # Public/Private 구분
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
}
```

**주요 차이:**
- OCI는 서브넷 생성 시 Route Table, Security List 직접 연결
- OCI는 `prohibit_public_ip_on_vnic`로 Public/Private 구분
- OCI는 Regional 또는 AD-specific 선택 가능

---

### Network Security Group

**Azure:**
```hcl
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "WireGuard"
    protocol                   = "Udp"
    destination_port_ranges    = ["51820"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    # ... more fields
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}
```

**OCI:**
```hcl
resource "oci_core_network_security_group" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "nsg-${var.project_name}"
}

resource "oci_core_network_security_group_security_rule" "wireguard" {
  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "INGRESS"
  protocol                  = "17"  # UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  udp_options {
    destination_port_range {
      min = 51820
      max = 51820
    }
  }
}
```

**주요 차이:**
- OCI는 Rule을 별도 리소스로 생성
- OCI는 Protocol을 번호로 지정 (TCP=6, UDP=17, ICMP=1)
- OCI NSG는 VNIC 레벨에서 적용 (서브넷이 아닌)
- OCI는 Security List (서브넷 레벨)와 NSG (VNIC 레벨) 두 가지 옵션

---

### Public IP

**Azure:**
```hcl
resource "azurerm_public_ip" "main" {
  name                = "pip-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "main" {
  # ...
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.main.id
  }
}
```

**OCI:**
```hcl
# Instance 생성 시 VNIC에 직접 할당
resource "oci_core_instance" "main" {
  create_vnic_details {
    assign_public_ip = true  # Ephemeral IP 자동 할당
  }
}

# Reserved IP가 필요한 경우만 별도 생성
resource "oci_core_public_ip" "main" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.main.private_ips[0].id
}
```

**주요 차이:**
- Azure는 Public IP를 먼저 생성 후 NIC에 연결
- OCI는 VNIC 생성 시 `assign_public_ip = true`로 자동 할당
- OCI Reserved IP는 인스턴스를 삭제해도 유지됨

---

### VNet Peering

**Azure:**
```hcl
resource "azurerm_virtual_network_peering" "vpn_to_node" {
  name                      = "peer-vpn-to-node"
  resource_group_name       = azurerm_resource_group.vpn.name
  virtual_network_name      = azurerm_virtual_network.vpn.name
  remote_virtual_network_id = azurerm_virtual_network.node.id
  allow_virtual_network_access = true
}

# 반대 방향도 생성
resource "azurerm_virtual_network_peering" "node_to_vpn" {
  # ...
}
```

**OCI (같은 리전):**
```hcl
resource "oci_core_local_peering_gateway" "vpn" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vpn.id
  display_name   = "lpg-vpn-to-node"
  peer_id        = oci_core_local_peering_gateway.node.id
}

resource "oci_core_local_peering_gateway" "node" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.node.id
  display_name   = "lpg-node-to-vpn"
}

# Route Table에 명시적 경로 추가 필요
resource "oci_core_route_table" "main" {
  route_rules {
    network_entity_id = oci_core_local_peering_gateway.vpn.id
    destination       = var.node_vcn_cidr
  }
}
```

**주요 차이:**
- OCI는 Local Peering Gateway (LPG) 생성
- OCI는 Route Table에 명시적으로 경로 추가 필요
- 다른 리전 간에는 DRG (Dynamic Routing Gateway) 필요

---

### Route Table

**Azure:**
```hcl
resource "azurerm_route_table" "main" {
  name                = "rt-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_route" "vpn_client" {
  name                   = "route-vpn-client"
  route_table_name       = azurerm_route_table.main.name
  resource_group_name    = azurerm_resource_group.main.name
  address_prefix         = "192.168.1.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.vpn_server_ip
}

resource "azurerm_subnet_route_table_association" "main" {
  subnet_id      = azurerm_subnet.main.id
  route_table_id = azurerm_route_table.main.id
}
```

**OCI:**
```hcl
resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "rt-${var.project_name}"

  # Route Rule을 내부에 정의
  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
  }

  route_rules {
    network_entity_id = oci_core_private_ip.vpn_server.id
    destination       = "192.168.1.0/24"
  }
}

# Subnet 생성 시 route_table_id로 연결
resource "oci_core_subnet" "main" {
  route_table_id = oci_core_route_table.main.id
}
```

**주요 차이:**
- Azure는 Route를 별도 리소스로 생성
- OCI는 Route Rule을 Route Table 내부에 정의
- OCI는 `network_entity_id`로 IGW, NAT GW, DRG, LPG, Private IP 등 지정

---

### Virtual Machine

**Azure:**
```hcl
resource "azurerm_linux_virtual_machine" "main" {
  name                  = "vm-${var.project_name}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = "Standard_B1s"
  admin_username        = var.username
  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = var.username
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(data.template_file.userdata.rendered)
}
```

**OCI:**
```hcl
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.vm_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "main" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E4.Flex"
  display_name        = "vm-${var.project_name}"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id              = oci_core_subnet.main.id
    assign_public_ip       = true
    private_ip             = var.vm_private_ip
    skip_source_dest_check = true  # IP forwarding
    nsg_ids                = [oci_core_network_security_group.main.id]
  }

  metadata = {
    ssh_authorized_keys = file(var.public_key_path)
    user_data           = base64encode(data.template_file.userdata.rendered)
  }
}
```

**주요 차이:**
- OCI는 **Availability Domain** 필수
- OCI는 **Shape** 개념 사용 (VM.Standard, VM.Optimized 등)
- OCI **Flex Shape**은 OCPU와 메모리를 유연하게 조정 가능
- OCI는 Image를 OCID로 지정 (data source로 조회)
- OCI는 NIC을 먼저 생성하지 않고 Instance와 함께 정의
- OCI는 `skip_source_dest_check = true`로 IP forwarding 활성화 (Wireguard 필수)
- OCI는 SSH Key와 cloud-init을 `metadata`에 포함

---

## Wireguard 특화 설정 비교

### IP Forwarding 활성화

| Azure | OCI |
|-------|-----|
| `enable_ip_forwarding = true` (NIC) | `skip_source_dest_check = true` (VNIC) |

### Security Rules (UDP 51820)

**Azure:**
```hcl
security_rule {
  protocol                = "Udp"
  destination_port_ranges = ["51820"]
}
```

**OCI:**
```hcl
udp_options {
  destination_port_range {
    min = 51820
    max = 51820
  }
}
```

---

## 비용 비교

### Azure

| 리소스 | 비용 (월) |
|--------|----------|
| B1s VM (1 vCPU, 1GB RAM) | ~$10 |
| Public IP (Static) | ~$3 |
| Storage (32GB SSD) | ~$1 |
| Outbound Transfer (5GB) | ~$1 |
| **총계** | **~$15/월** |

### OCI Always Free Tier

| 리소스 | 비용 (월) |
|--------|----------|
| VM.Standard.E2.1.Micro (1/8 OCPU, 1GB RAM) | **무료** (최대 2개) |
| Public IP (Ephemeral) | **무료** |
| Boot Volume (50GB) | **무료** (200GB까지) |
| Outbound Transfer (10TB) | **무료** |
| **총계** | **$0/월** |

**결론**: OCI Always Free Tier를 사용하면 동일한 Wireguard VPN 인프라를 **무료**로 운영 가능

---

## 성능 비교

### VM 성능

| 항목 | Azure B1s | OCI VM.Standard.E2.1.Micro | OCI VM.Standard.E4.Flex (1 OCPU) |
|------|-----------|---------------------------|----------------------------------|
| CPU | 1 vCPU (Burstable) | 1/8 OCPU | 1 OCPU |
| 메모리 | 1GB | 1GB | 6GB (조정 가능) |
| 네트워크 | 640 Mbps | 480 Mbps | 1 Gbps |
| Always Free | ❌ | ✅ (2개) | ❌ |

### 네트워크 성능

| 항목 | Azure | OCI |
|------|-------|-----|
| VNet 간 대역폭 | 지역 간: 100 Mbps+ | LPG: 1 Gbps+, DRG: 10 Gbps |
| Public IP 대역폭 | VM 크기에 따름 | VM 크기에 따름 |
| 레이턴시 (서울) | ~1ms (같은 리전) | ~1ms (같은 리전) |

---

## 관리 및 운영 비교

### 인증 방식

| Azure | OCI |
|-------|-----|
| Service Principal (client_id + client_secret) | API Key (private_key + fingerprint) |
| Azure AD 통합 | OCI IAM |
| RBAC | IAM Policies |

### CLI 도구

| Azure | OCI |
|-------|-----|
| Azure CLI (`az`) | OCI CLI (`oci`) |
| PowerShell | - |

### 모니터링

| Azure | OCI |
|-------|-----|
| Azure Monitor | OCI Monitoring |
| Application Insights | - |
| Log Analytics | Logging Analytics |

---

## 마이그레이션 복잡도

### 쉬운 부분 ✅
- VCN, Subnet, Route Table 개념 유사
- Terraform 코드 구조 유사
- Wireguard 설정 동일 (cloud-init)

### 주의 필요 ⚠️
- Provider 설정 및 인증 방식 다름
- Resource 네이밍 규칙 다름 (azurerm_ vs oci_core_)
- Public IP 할당 방식 다름
- VNet Peering → LPG 변환 (리전 간에는 DRG 필요)

### 어려운 부분 ❌
- Security List vs NSG 선택
- Availability Domain 개념 이해
- Shape 선택 및 최적화
- OCI API Key 기반 인증 설정

---

## 권장 사항

### 마이그레이션 순서
1. ✅ OCI 계정 생성 및 Always Free Tier 활성화
2. ✅ API Key 생성 및 설정
3. ✅ VPN 서버부터 배포 (단독 테스트)
4. ✅ 클라이언트 연결 테스트
5. ✅ Node 네트워크 배포 및 Peering 설정
6. ✅ 전체 통합 테스트

### 최적화 팁
- Always Free Tier 최대 활용 (VM 2개 무료)
- Flex Shape으로 필요에 따라 리소스 조정
- Regional Subnet 사용 (고가용성)
- NSG 사용 (Security List보다 세밀한 제어)

### 주의사항
- OCI Always Free는 30일 Trial과 다름 (영구 무료)
- Always Free 리소스는 48시간 미사용 시 자동 중지될 수 있음
- Availability Domain별 quota 확인 필요

---

## 결론

**OCI 마이그레이션의 장점:**
1. ✅ **비용 절감**: Always Free Tier로 무료 운영 가능
2. ✅ **성능**: Flex Shape으로 유연한 리소스 조정
3. ✅ **보안**: NSG와 Security List 이중 보안
4. ✅ **확장성**: 쉬운 스케일 업/다운

**고려사항:**
1. ⚠️ OCI 학습 곡선 (새로운 개념)
2. ⚠️ Azure와 다른 네트워킹 모델
3. ⚠️ Region/AD별 리소스 가용성 확인 필요

**최종 권장:**
- 개발/테스트 환경: OCI Always Free Tier 강력 권장
- 프로덕션 환경: 비용 대비 성능 우수, 마이그레이션 가치 있음
