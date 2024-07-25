variable "project_name" { type = string }
variable "username" { type = string }
variable "vm_size" { type = string }

variable "onprem_address_prefix" { type = string }
variable "vpn_client_address_prefix" { type = string }
variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_azure.pub"
}

variable "gpu_tenant" { type = map(any) }
variable "gpu_variables" { type = map(any) }

variable "default_tenant" { type = map(any) }
variable "default_variables" { type = map(any) }