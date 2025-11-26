output "subnet_id" {
  description = "Node Subnet OCID"
  value       = oci_core_subnet.node.id
}

output "subnet_cidr" {
  description = "Node Subnet CIDR"
  value       = oci_core_subnet.node.cidr_block
}

output "route_table_id" {
  description = "Route Table OCID"
  value       = oci_core_route_table.node.id
}

output "nsg_id" {
  description = "Network Security Group OCID"
  value       = oci_core_network_security_group.node.id
}

output "security_list_id" {
  description = "Security List OCID"
  value       = oci_core_security_list.node.id
}
