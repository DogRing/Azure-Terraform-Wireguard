variable "project_name" { type = string }
variable "network" { type = map(string) }
variable "vm_data" { type = map(string) }
variable "route_address_prefix" { type = list(string) }
variable "wg_peers" { type = list(map(string)) }