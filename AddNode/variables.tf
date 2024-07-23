# VPN Variables
variable "vpn_resource_group_name" { type = string }
variable "vpn_virtual_network_name" { type = string }
variable "vpn_subnet_name" { type = string }
variable "vpn_nic_name" { type = string }

# Node Variables
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project_name" { type = string }
variable "node_count" { type = number }

variable "node_vnet_address" { type = string }
variable "node_subnet_address" { type = list(string) }

variable "vm_image" { type = string }
variable "username" { type = string }
variable "public_key_path" {
  type = string
  default = "~/.ssh/id_azure.pub"
}
