variable "tenants" { type = map(map(string)) }
variable "tf_config" { type = map(map(string)) } 
variable "vpn_config" { type = map(string) }
variable "vm_config" { type = map(map(string)) }
variable "etc_hosts" { type = map(string) }