terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# VCN (Virtual Cloud Network)
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "vcn-${var.project_name}"
  dns_label      = replace(var.project_name, "-", "")
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "igw-${var.project_name}"
  enabled        = true
}

# Route Table
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
}

# Security List
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "seclist-${var.project_name}"

  # Egress: Allow all outbound
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }

  # Ingress: Allow Wireguard UDP
  ingress_security_rules {
    protocol    = "17"  # UDP
    source      = "0.0.0.0/0"
    description = "Wireguard VPN"

    udp_options {
      min = var.vpn_port
      max = var.vpn_port
    }
  }

  # Ingress: Allow ICMP
  ingress_security_rules {
    protocol    = "1"  # ICMP
    source      = "0.0.0.0/0"
    description = "ICMP for ping"
  }
}

# Network Security Group (for more granular control)
resource "oci_core_network_security_group" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "nsg-${var.project_name}"
}

# NSG Rule: Wireguard Inbound
resource "oci_core_network_security_group_security_rule" "wireguard_inbound" {
  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "INGRESS"
  protocol                  = "17"  # UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Wireguard VPN inbound"

  udp_options {
    destination_port_range {
      min = var.vpn_port
      max = var.vpn_port
    }
  }
}

# NSG Rule: SSH Inbound (conditional)
resource "oci_core_network_security_group_security_rule" "ssh_inbound" {
  count = length(var.enable_ssh)

  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "INGRESS"
  protocol                  = "6"  # TCP
  source                    = var.enable_ssh[count.index]
  source_type               = "CIDR_BLOCK"
  description               = "SSH access ${count.index}"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# NSG Rule: Allow all outbound
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.main.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound"
}

# VPN Server Public Subnet
resource "oci_core_subnet" "vpn" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.vpn_subnet_cidr
  display_name               = "subnet-vpn-${var.project_name}"
  dns_label                  = "subnetvpn${replace(var.project_name, "-", "")}"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
}
