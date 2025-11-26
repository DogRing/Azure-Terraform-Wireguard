output "vpn_public_ip" {
  description = "VPN server public IP address"
  value       = module.wireguard.public_ip
}

output "vpn_private_ip" {
  description = "VPN server private IP address"
  value       = module.network.vpn_private_ip
}

output "vpn_server_public_key" {
  description = "Wireguard server public key"
  value       = module.network.vpn_public_key
  sensitive   = true
}

output "vpn_server_private_key" {
  description = "Wireguard server private key"
  value       = module.network.vpn_private_key
  sensitive   = true
}

output "vcn_id" {
  description = "VCN OCID"
  value       = module.network.vcn_id
}

output "subnet_id" {
  description = "Subnet OCID"
  value       = module.network.subnet_id
}

output "instance_id" {
  description = "Compute instance OCID"
  value       = module.wireguard.instance_id
}

output "vpn_config" {
  description = "VPN configuration for node networks"
  value = {
    compartment_id = var.compartment_id
    vcn_id         = module.network.vcn_id
    subnet_id      = module.network.subnet_id
    private_ip     = module.network.vpn_private_ip
  }
}
