output "instance_id" {
  description = "Compute instance OCID"
  value       = oci_core_instance.main.id
}

output "public_ip" {
  description = "Instance public IP address"
  value       = data.oci_core_vnic.instance_vnic.public_ip_address
}

output "private_ip" {
  description = "Instance private IP address"
  value       = data.oci_core_vnic.instance_vnic.private_ip_address
}
