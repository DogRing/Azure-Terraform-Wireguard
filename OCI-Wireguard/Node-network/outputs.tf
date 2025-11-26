output "subnet_id" {
  description = "Node Subnet OCID"
  value       = module.network.subnet_id
}

output "route_table_id" {
  description = "Route Table OCID"
  value       = module.network.route_table_id
}

output "nsg_id" {
  description = "Network Security Group OCID"
  value       = module.network.nsg_id
}

output "subnet_cidr" {
  description = "Node Subnet CIDR"
  value       = module.network.subnet_cidr
}
