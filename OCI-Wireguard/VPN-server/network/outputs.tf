output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.main.id
}

output "subnet_id" {
  description = "Subnet OCID"
  value       = oci_core_subnet.main.id
}

output "nsg_id" {
  description = "Network Security Group OCID"
  value       = oci_core_network_security_group.main.id
}

output "vpn_private_ip" {
  description = "VPN server private IP"
  value       = var.vm_private_ip
}

output "vpn_port" {
  description = "Wireguard VPN port"
  value       = var.vpn_port
}

output "vpn_public_key" {
  description = "Wireguard server public key"
  value       = data.local_file.public_key.content
  sensitive   = true
}

output "vpn_private_key" {
  description = "Wireguard server private key"
  value       = var.private_key == "" ? data.local_file.private_key[0].content : var.private_key
  sensitive   = true
}

output "compartment_id" {
  description = "Compartment OCID"
  value       = var.compartment_id
}

output "region" {
  description = "OCI Region"
  value       = var.region
}
