variable "project_name" { type = string }
variable "location" { type = string }
variable "address_space" { type = string }
variable "subnet_addresses" { type = string }
variable "route_addresses" { type = list(string) }
variable "vpn_config" { type = map(string) }