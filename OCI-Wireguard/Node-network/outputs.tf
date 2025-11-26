output "vcn_id" {
  description = "Node VCN OCID"
  value       = module.network.vcn_id
}

output "subnet_id" {
  description = "Node Subnet OCID"
  value       = module.network.subnet_id
}

output "lpg_id" {
  description = "Local Peering Gateway OCID"
  value       = module.network.lpg_id
}

output "route_table_id" {
  description = "Route Table OCID"
  value       = module.network.route_table_id
}
