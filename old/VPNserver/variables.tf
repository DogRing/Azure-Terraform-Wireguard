variable "project_name" { type = string }
variable "username" { type = string }
variable "vm_size" { type = string }

variable "route_address_prefix" { type = list(string) }
variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_azure.pub"
}

variable "gpu_tenant" { type = map(string) }
variable "gpu_variables" { type = map(string) }

variable "default_tenant" { type = map(string) }
variable "default_variables" { type = map(string) }