variable "project_name" { type = string }
variable "location" { type = string }

variable "vnet_address_space" { type = string }
variable "subnet_address_prefix" { type = string }
variable "vm_private_ip" { type = string }
variable "vpn_interface_ip" { type = string }
variable "allowed_ips" { type = string }
variable "vpn_port" { type = string }

variable "key_gen" { 
  type = string 
  default = ""
}
variable "private_key" { 
  type = string
  default = ""
  validation {
    condition = (
      (var.key_gen == "" && var.private_key != "") ||
      (var.private_key == "" && var.key_gen != "")  
    )
    error_message = "Either 'first_variable' or 'second_variable' must be non-empty."
  }
}

variable "enable-igw" { 
  type = bool
  default = false
}
variable "enable-ssh" {
  type = list(string)
  default = []
}