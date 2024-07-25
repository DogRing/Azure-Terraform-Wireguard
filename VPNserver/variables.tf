variable "gpu_tenant" { type = map }
variable "gpu_variables" { type = map }

variable "default_tenant" { type = map }
variable "default_variables" { type = map }

variable "onprem_address_prefix" { type = string }
variable "vpn_client_address_prefix" { type = string }

variable "username" { type = string }
variable "vm_size" { type = string }
variable "public_key_path" {
  type = string
  default = "~/.ssh/id_azure.pub"
}
