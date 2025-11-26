terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# Reference existing VPN VCN (created by VPN-server)
data "oci_core_vcn" "vpn" {
  vcn_id = var.vpn_vcn_id
}

# Get VPN server's private IP for routing
data "oci_core_private_ips" "vpn_server" {
  ip_address = var.vpn_server_private_ip
  subnet_id  = data.oci_core_subnets.vpn_subnet.subnets[0].id
}

# Get VPN subnet (to find private IPs)
data "oci_core_subnets" "vpn_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = var.vpn_vcn_id

  filter {
    name   = "cidr_block"
    values = [var.vpn_subnet_cidr]
  }
}

# Route Table for Node Subnet
resource "oci_core_route_table" "node" {
  compartment_id = var.compartment_id
  vcn_id         = var.vpn_vcn_id
  display_name   = "rt-${var.project_name}"

  # Default route to Internet Gateway (inherit from VPN VCN)
  dynamic "route_rules" {
    for_each = data.oci_core_vcn.vpn.default_route_table_id != "" ? [1] : []
    content {
      network_entity_id = data.oci_core_internet_gateways.vpn_igw.internet_gateways[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      description       = "Default route to Internet"
    }
  }

  # Routes for VPN clients - send traffic to VPN server
  dynamic "route_rules" {
    for_each = var.route_cidrs
    content {
      network_entity_id = data.oci_core_private_ips.vpn_server.private_ips[0].id
      destination       = route_rules.value
      destination_type  = "CIDR_BLOCK"
      description       = "Route to VPN clients via VPN server"
    }
  }
}

# Get Internet Gateway from VPN VCN
data "oci_core_internet_gateways" "vpn_igw" {
  compartment_id = var.compartment_id
  vcn_id         = var.vpn_vcn_id
}

# Security List for Node Subnet
resource "oci_core_security_list" "node" {
  compartment_id = var.compartment_id
  vcn_id         = var.vpn_vcn_id
  display_name   = "seclist-${var.project_name}"

  # Egress: Allow all outbound
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }

  # Ingress: Allow from VPN server subnet
  ingress_security_rules {
    protocol    = "all"
    source      = var.vpn_subnet_cidr
    description = "Allow all from VPN server subnet"
  }

  # Ingress: Allow from VPN clients
  ingress_security_rules {
    protocol    = "all"
    source      = var.vpn_client_cidr
    description = "Allow all from VPN clients"
  }

  # Ingress: Allow within same subnet
  ingress_security_rules {
    protocol    = "all"
    source      = var.node_subnet_cidr
    description = "Allow traffic within node subnet"
  }

  # Ingress: Allow ICMP
  ingress_security_rules {
    protocol    = "1"  # ICMP
    source      = "0.0.0.0/0"
    description = "ICMP for ping"
  }
}

# Network Security Group for Node Resources
resource "oci_core_network_security_group" "node" {
  compartment_id = var.compartment_id
  vcn_id         = var.vpn_vcn_id
  display_name   = "nsg-${var.project_name}"
}

# NSG Rule: Allow from VPN server
resource "oci_core_network_security_group_security_rule" "vpn_server_inbound" {
  network_security_group_id = oci_core_network_security_group.node.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vpn_subnet_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Allow all from VPN server subnet"
}

# NSG Rule: Allow from VPN clients
resource "oci_core_network_security_group_security_rule" "vpn_clients_inbound" {
  network_security_group_id = oci_core_network_security_group.node.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vpn_client_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Allow all from VPN clients"
}

# NSG Rule: Allow within subnet
resource "oci_core_network_security_group_security_rule" "intra_subnet" {
  network_security_group_id = oci_core_network_security_group.node.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.node_subnet_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Allow traffic within node subnet"
}

# NSG Rule: Allow all outbound
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.node.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound"
}

# Node Subnet (in existing VPN VCN)
resource "oci_core_subnet" "node" {
  compartment_id             = var.compartment_id
  vcn_id                     = var.vpn_vcn_id
  cidr_block                 = var.node_subnet_cidr
  display_name               = "subnet-${var.project_name}"
  dns_label                  = "subnet${replace(var.project_name, "-", "")}"
  prohibit_public_ip_on_vnic = false  # Set to true for private subnet
  route_table_id             = oci_core_route_table.node.id
  security_list_ids          = [oci_core_security_list.node.id]
}
