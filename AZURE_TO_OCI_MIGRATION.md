# Azure to Oracle Cloud Infrastructure (OCI) Migration Guide

## 개요
이 문서는 Azure 기반 Wireguard VPN 인프라를 Oracle Cloud Infrastructure (OCI)로 마이그레이션하기 위한 가이드입니다.

## 주요 리소스 매핑

### 1. 네트워크 리소스

#### Resource Group → Compartment
**Azure:**
```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}"
  location = var.location
}
```

**OCI:**
```hcl
# OCI는 Compartment를 사용하며, 기존 compartment_id를 변수로 받음
variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}
```

**차이점:**
- Azure: 리전별로 Resource Group 생성
- OCI: Compartment는 리전과 무관한 논리적 컨테이너, 계층 구조 지원

---

#### Virtual Network → Virtual Cloud Network (VCN)
**Azure:**
```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}"
  address_space       = [ var.vnet_address_space ]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
```

**OCI:**
```hcl
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr_block]
  display_name   = "vcn-${var.project_name}"
  dns_label      = var.dns_label
}
```

**차이점:**
- Azure: `address_space` (복수형 배열)
- OCI: `cidr_blocks` (복수 CIDR 지원), `dns_label` 필수 (DNS 호스트 이름용)

---

#### Subnet
**Azure:**
```hcl
resource "azurerm_subnet" "main" {
  name                 = "subnet-${var.project_name}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [ var.subnet_address_prefix ]
}
```

**OCI:**
```hcl
resource "oci_core_subnet" "main" {
  compartment_id      = var.compartment_id
  vcn_id              = oci_core_vcn.main.id
  cidr_block          = var.subnet_cidr
  display_name        = "subnet-${var.project_name}"

  # Regional subnet (권장) 또는 AD-specific
  # availability_domain = data.oci_identity_availability_domain.ad.name

  # Public/Private 구분
  prohibit_public_ip_on_vnic = false  # true for private subnet

  # Security List 연결
  security_list_ids = [oci_core_security_list.main.id]

  # Route Table 연결
  route_table_id = oci_core_route_table.main.id

  dns_label = "subnet${var.project_name}"
}
```

**차이점:**
- Azure: Resource Group과 VNet 이름으로 참조
- OCI:
  - Regional 또는 AD-specific 선택 가능
  - `prohibit_public_ip_on_vnic`으로 Public/Private 구분
  - Security List와 Route Table을 서브넷 생성 시 직접 연결
  - DNS label 필요

---

#### Network Security Group
**Azure:**
```hcl
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "WireGuard-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = [ var.vpn_port ]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}
```

**OCI Option 1 - Security List (서브넷 레벨):**
```hcl
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "seclist-${var.project_name}"

  # Ingress Rules
  ingress_security_rules {
    protocol    = "17"  # UDP
    source      = "0.0.0.0/0"
    description = "WireGuard Inbound"

    udp_options {
      min = var.vpn_port
      max = var.vpn_port
    }
  }

  # Egress Rules
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound"
  }
}
```

**OCI Option 2 - Network Security Group (VNIC 레벨, 권장):**
```hcl
resource "oci_core_network_security_group" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "nsg-${var.project_name}"
}

resource "oci_core_network_security_group_security_rule" "wireguard_inbound" {
  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "INGRESS"
  protocol                  = "17"  # UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"

  udp_options {
    destination_port_range {
      min = var.vpn_port
      max = var.vpn_port
    }
  }
}
```

**차이점:**
- Azure: NSG를 서브넷 또는 NIC에 연결
- OCI:
  - **Security List**: 서브넷 레벨, 자동으로 모든 VNIC에 적용
  - **NSG**: VNIC 레벨, 보다 세밀한 제어 가능 (권장)
  - Protocol은 번호로 지정 (TCP=6, UDP=17, ICMP=1, ALL=all)
  - Stateful by default

---

#### Public IP
**Azure:**
```hcl
resource "azurerm_public_ip" "main" {
  name                = "pip-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}
```

**OCI:**
```hcl
# OCI는 Public IP를 별도로 생성하지 않고 VNIC에 할당
# Reserved Public IP가 필요한 경우:
resource "oci_core_public_ip" "main" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"  # or "EPHEMERAL"
  display_name   = "pip-${var.project_name}"

  # Private IP와 연결
  private_ip_id = data.oci_core_private_ips.main.private_ips[0].id
}
```

**차이점:**
- Azure: Public IP를 먼저 생성 후 NIC에 연결
- OCI:
  - VNIC 생성 시 `assign_public_ip = true`로 자동 할당 (Ephemeral)
  - Reserved IP가 필요한 경우만 별도 리소스로 생성
  - Lifetime: RESERVED (영구) vs EPHEMERAL (임시)

---

#### Network Interface → VNIC
**Azure:**
```hcl
resource "azurerm_network_interface" "main" {
  name                 = "nic-${var.project_name}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_private_ip
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}
```

**OCI:**
```hcl
# OCI는 VNIC을 Compute Instance와 함께 생성하거나 별도로 생성
# Instance 생성 시 Primary VNIC는 자동 생성됨
resource "oci_core_instance" "main" {
  # ... other config ...

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    display_name     = "vnic-${var.project_name}"
    assign_public_ip = true
    private_ip       = var.vm_private_ip
    skip_source_dest_check = true  # IP forwarding 활성화
    nsg_ids          = [oci_core_network_security_group.main.id]
  }
}

# Secondary VNIC가 필요한 경우:
resource "oci_core_vnic_attachment" "secondary" {
  instance_id  = oci_core_instance.main.id
  display_name = "vnic-secondary"

  create_vnic_details {
    subnet_id        = oci_core_subnet.secondary.id
    assign_public_ip = false
  }
}
```

**차이점:**
- Azure: NIC을 먼저 생성 후 VM에 연결
- OCI:
  - Primary VNIC은 Instance 생성 시 함께 정의
  - `skip_source_dest_check = true`로 IP forwarding 활성화 (Wireguard에 필수)
  - NSG를 VNIC 레벨에서 직접 연결

---

#### VNet Peering → Local Peering Gateway (LPG)
**Azure:**
```hcl
resource "azurerm_virtual_network_peering" "vpn_to_node" {
  name                      = "peer-vpn-to-node"
  resource_group_name       = azurerm_resource_group.vpn.name
  virtual_network_name      = azurerm_virtual_network.vpn.name
  remote_virtual_network_id = azurerm_virtual_network.node.id
  allow_virtual_network_access = true
}
```

**OCI (같은 리전):**
```hcl
# VPN VCN의 LPG
resource "oci_core_local_peering_gateway" "vpn" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vpn.id
  display_name   = "lpg-vpn-to-node"

  peer_id = oci_core_local_peering_gateway.node.id
}

# Node VCN의 LPG
resource "oci_core_local_peering_gateway" "node" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.node.id
  display_name   = "lpg-node-to-vpn"
}

# Route Table에 Peering 경로 추가
resource "oci_core_route_table" "vpn" {
  # ... other config ...

  route_rules {
    network_entity_id = oci_core_local_peering_gateway.vpn.id
    destination       = var.node_vcn_cidr
    destination_type  = "CIDR_BLOCK"
  }
}
```

**OCI (다른 리전 - Remote Peering):**
```hcl
resource "oci_core_drg" "main" {
  compartment_id = var.compartment_id
  display_name   = "drg-${var.project_name}"
}

resource "oci_core_drg_attachment" "vpn" {
  drg_id = oci_core_drg.main.id
  vcn_id = oci_core_vcn.vpn.id
  display_name = "drg-attachment-vpn"
}

resource "oci_core_remote_peering_connection" "source" {
  compartment_id = var.compartment_id
  drg_id         = oci_core_drg.main.id
  display_name   = "rpc-source"
  peer_id        = oci_core_remote_peering_connection.destination.id
  peer_region_name = var.peer_region
}
```

**차이점:**
- Azure: VNet Peering이 리전 간 자동 지원
- OCI:
  - **같은 리전**: Local Peering Gateway (LPG) 사용
  - **다른 리전**: Dynamic Routing Gateway (DRG) + Remote Peering Connection (RPC) 필요
  - Route Table에 명시적으로 peering 경로 추가 필요

---

#### Route Table
**Azure:**
```hcl
resource "azurerm_route_table" "main" {
  name                = "rt-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_route" "vpn_client" {
  name                   = "route-vpn-client"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.main.name
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

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    description       = "Default route to Internet"
  }

  route_rules {
    network_entity_id = oci_core_private_ip.vpn_server.id
    destination       = "192.168.1.0/24"
    destination_type  = "CIDR_BLOCK"
    description       = "Route to VPN clients"
  }
}

# Subnet과 Route Table은 Subnet 생성 시 연결
```

**차이점:**
- Azure: Route를 별도 리소스로 생성
- OCI:
  - Route Rule을 Route Table 내부에 정의
  - `network_entity_id`: IGW, NAT GW, DRG, LPG, Private IP 등
  - Subnet 생성 시 `route_table_id`로 연결

---

### 2. 컴퓨팅 리소스

#### Linux Virtual Machine → Compute Instance
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
    name                 = "osdisk-${var.project_name}"
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
# Availability Domain 조회
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

resource "oci_core_instance" "main" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = "VM.Standard.E4.Flex"
  display_name        = "vm-${var.project_name}"

  # Flexible shape의 경우 OCPU와 메모리 지정
  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  # Boot Volume
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  # Primary VNIC
  create_vnic_details {
    subnet_id              = oci_core_subnet.main.id
    display_name           = "vnic-${var.project_name}"
    assign_public_ip       = true
    private_ip             = var.vm_private_ip
    skip_source_dest_check = true  # IP forwarding for Wireguard
    nsg_ids                = [oci_core_network_security_group.main.id]
  }

  # SSH Key
  metadata = {
    ssh_authorized_keys = file(var.public_key_path)
    user_data           = base64encode(data.template_file.userdata.rendered)
  }

  # 인스턴스 재생성 시 Public IP 유지
  preserve_boot_volume = false
}

# Ubuntu 이미지 조회
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
```

**차이점:**
- Azure:
  - `size`로 VM 크기 지정 (예: Standard_B1s)
  - Image는 publisher/offer/sku로 지정
  - NIC을 먼저 생성 후 연결

- OCI:
  - **Shape**: VM.Standard (AMD), VM.Standard.E (AMD Flex), VM.Optimized 등
  - **Flex Shape**: OCPU와 메모리를 유연하게 조정 가능
  - **Availability Domain** 필수 (AD 1개 리전도 있음)
  - Image는 OCID로 지정 (data source로 조회)
  - VNIC은 인스턴스 생성 시 함께 정의
  - `metadata`에 SSH 키와 user_data 포함

---

### 3. 스토리지 리소스

**Azure Storage Account → OCI Object Storage or File Storage**

**Azure (File Share):**
```hcl
resource "azurerm_storage_account" "main" {
  name                     = "staccount${var.project_name}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "main" {
  name                 = "share-${var.project_name}"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100
}
```

**OCI Object Storage (파일 저장용):**
```hcl
resource "oci_objectstorage_bucket" "main" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "bucket-${var.project_name}"
  access_type    = "NoPublicAccess"  # or "ObjectRead" for public
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}
```

**OCI File Storage (NFS):**
```hcl
resource "oci_file_storage_file_system" "main" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "fs-${var.project_name}"
}

resource "oci_file_storage_mount_target" "main" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_id           = oci_core_subnet.main.id
  display_name        = "mt-${var.project_name}"
}

resource "oci_file_storage_export" "main" {
  export_set_id  = oci_file_storage_mount_target.main.export_set_id
  file_system_id = oci_file_storage_file_system.main.id
  path           = "/data"
}
```

**차이점:**
- Azure: Storage Account로 Blob, File, Queue 등 통합 관리
- OCI:
  - **Object Storage**: S3와 유사, REST API 접근
  - **File Storage**: NFS 프로토콜, VM 마운트 용
  - **Block Volume**: 추가 디스크 (Azure Managed Disk와 유사)

---

## Provider 설정

### Azure Provider
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  features {}
}
```

### OCI Provider
```hcl
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
```

**인증 방식 차이:**
- Azure: Service Principal (client_id + client_secret)
- OCI: API Key (private_key + fingerprint) 또는 Instance Principal

---

## Wireguard 특화 설정

### IP Forwarding

**Azure:**
- NIC에서 `enable_ip_forwarding = true`

**OCI:**
- VNIC에서 `skip_source_dest_check = true`

### Security Rules

**Azure NSG (UDP 51820):**
```hcl
security_rule {
  protocol                   = "Udp"
  destination_port_ranges    = ["51820"]
  source_address_prefix      = "*"
}
```

**OCI NSG:**
```hcl
udp_options {
  destination_port_range {
    min = 51820
    max = 51820
  }
}
```

---

## 마이그레이션 체크리스트

### 사전 준비
- [ ] OCI Tenancy 및 Compartment 생성
- [ ] API Key 생성 및 설정
- [ ] Region 선택 (서울: ap-seoul-1, 춘천: ap-chuncheon-1)
- [ ] VCN CIDR 블록 계획

### 네트워크 설정
- [ ] VCN 생성
- [ ] Subnet 생성 (Public/Private 구분)
- [ ] Internet Gateway 생성 및 연결
- [ ] Route Table 설정
- [ ] Security List 또는 NSG 설정
- [ ] VCN Peering 설정 (필요 시)

### 컴퓨팅 설정
- [ ] Ubuntu 이미지 선택
- [ ] Shape 선택 (Flex Shape 권장)
- [ ] SSH Key 준비
- [ ] Cloud-init (userdata) 스크립트 검증
- [ ] Compute Instance 생성

### Wireguard 설정
- [ ] IP Forwarding 활성화 (`skip_source_dest_check`)
- [ ] UDP 포트 오픈 (기본 51820)
- [ ] Wireguard 키 생성 및 관리
- [ ] Peer 설정

### 후속 작업
- [ ] DNS 설정
- [ ] 모니터링 설정
- [ ] 백업 정책 수립
- [ ] 비용 최적화 검토

---

## 주요 고려사항

1. **비용**: OCI Always Free Tier 활용 가능
   - VM.Standard.E2.1.Micro (AMD) 2개 무료
   - 10TB 아웃바운드 트래픽/월

2. **성능**: Flex Shape으로 필요에 따라 OCPU/메모리 조정

3. **보안**:
   - NSG 권장 (Security List보다 세밀한 제어)
   - Private Subnet + NAT Gateway 고려

4. **가용성**:
   - Regional Subnet 권장
   - 여러 AD에 인스턴스 분산 배포

5. **네트워크**:
   - VCN은 리전별로 생성
   - 리전 간 통신은 DRG + RPC 필요
