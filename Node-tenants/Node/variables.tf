variable "project_name" { type = string }
variable "node_count" { type = number }

variable "location" { type = string }
variable "address_space" { type = string }
variable "subnet_addresses" { type = list(string) }
variable "route_addresses" { type = list(string) }

variable "vpn_config" { type = map(string) }
variable "vm_config" { type = map(string) }
variable "microk8s" {
  type = bool
  default = false
}
variable "gpu" { 
  type = bool
  default = false
}