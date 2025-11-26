output "vcn_id" {
  description = "Node VCN OCID"
  value       = oci_core_vcn.node.id
}

output "subnet_id" {
  description = "Node Subnet OCID"
  value       = oci_core_subnet.node.id
}

output "nsg_id" {
  description = "Network Security Group OCID"
  value       = oci_core_network_security_group.node.id
}

output "lpg_id" {
  description = "Local Peering Gateway OCID (Node side)"
  value       = oci_core_local_peering_gateway.node.id
}

output "route_table_id" {
  description = "Route Table OCID"
  value       = oci_core_route_table.node.id
}
