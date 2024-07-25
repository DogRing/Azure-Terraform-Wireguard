# VPN Variables
variable "vpn_resource_group_name" { type = string }
variable "vpn_virtual_network_name" { type = string }
variable "vpn_subnet_name" { type = string }
variable "vpn_nic_name" { type = string }

# tenants
variable "default_tenant" { type = map }
variable "gpu_tenant" { type = map }

# shared variables
variable "project_name" { type = string }
variable "username" { type = string }
variable "public_key_path" {
  type = string
  default = "~/.ssh/id_azure.pub"
}

# tenant variables
variable "default_variables" { type = map }
variable "default_route_addresses" { type = list }

variable "gpu_variables" { type = map }
variable "gpu_route_addresses" { type = list }