terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# Node VCN
resource "oci_core_vcn" "node" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "vcn-${var.project_name}"
  dns_label      = replace(var.project_name, "-", "")
}

# Node Subnet
resource "oci_core_subnet" "node" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.node.id
  cidr_block                 = var.subnet_cidr
  display_name               = "subnet-${var.project_name}"
  dns_label                  = "subnet${replace(var.project_name, "-", "")}"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.node.id
  security_list_ids          = [oci_core_security_list.node.id]
}

# Security List - Allow VPN traffic
resource "oci_core_security_list" "node" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.node.id
  display_name   = "seclist-${var.project_name}"

  # Allow all outbound
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }

  # Allow VPN traffic
  ingress_security_rules {
    protocol    = "all"
    source      = var.vpn_client_cidr
    description = "Allow VPN traffic"
  }

  # Allow ICMP
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "ICMP for ping"
  }
}

# Network Security Group
resource "oci_core_network_security_group" "node" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.node.id
  display_name   = "nsg-${var.project_name}"
}

# NSG Rule: Allow VPN traffic
resource "oci_core_network_security_group_security_rule" "vpn_inbound" {
  network_security_group_id = oci_core_network_security_group.node.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vpn_client_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Allow VPN traffic"
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

# Local Peering Gateway - Node side
resource "oci_core_local_peering_gateway" "node" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.node.id
  display_name   = "lpg-${var.project_name}-to-vpn"
}

# Local Peering Gateway - VPN side
resource "oci_core_local_peering_gateway" "vpn" {
  compartment_id = var.vpn_config.compartment_id
  vcn_id         = var.vpn_config.vcn_id
  display_name   = "lpg-vpn-to-${var.project_name}"
  peer_id        = oci_core_local_peering_gateway.node.id
}

# Route Table
resource "oci_core_route_table" "node" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.node.id
  display_name   = "rt-${var.project_name}"

  # Route VPN client traffic through LPG
  dynamic "route_rules" {
    for_each = var.route_cidrs
    content {
      network_entity_id = oci_core_local_peering_gateway.node.id
      destination       = route_rules.value
      destination_type  = "CIDR_BLOCK"
      description       = "Route to VPN clients"
    }
  }
}

# Data source to get VPN VCN route table
data "oci_core_route_tables" "vpn" {
  compartment_id = var.vpn_config.compartment_id
  vcn_id         = var.vpn_config.vcn_id
}

# Get the default route table for VPN VCN
locals {
  vpn_default_route_table_id = data.oci_core_route_tables.vpn.route_tables[0].id
}

# Add route to VPN VCN route table for Node network
resource "oci_core_route_table" "vpn_updated" {
  compartment_id = var.vpn_config.compartment_id
  vcn_id         = var.vpn_config.vcn_id
  display_name   = "rt-vpn-updated"

  # Preserve existing routes (Internet Gateway)
  dynamic "route_rules" {
    for_each = data.oci_core_route_tables.vpn.route_tables[0].route_rules
    content {
      network_entity_id = route_rules.value.network_entity_id
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      description       = route_rules.value.description
    }
  }

  # Add route to Node network
  route_rules {
    network_entity_id = oci_core_local_peering_gateway.vpn.id
    destination       = var.vcn_cidr
    destination_type  = "CIDR_BLOCK"
    description       = "Route to ${var.project_name} network"
  }
}

# Update VPN subnet to use the new route table
data "oci_core_subnets" "vpn" {
  compartment_id = var.vpn_config.compartment_id
  vcn_id         = var.vpn_config.vcn_id
}

# Note: This will replace the route table association
# You may need to manually update the subnet's route table in production
resource "null_resource" "update_vpn_subnet_route_table" {
  triggers = {
    route_table_id = oci_core_route_table.vpn_updated.id
    subnet_id      = var.vpn_config.subnet_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "VPN subnet route table should be updated to: ${oci_core_route_table.vpn_updated.id}"
      echo "Please update the VPN subnet route table manually or use the OCI Console/API"
    EOT
  }
}
