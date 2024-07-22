variable "project_name" {
  type = string
  default = "VPN"
}

variable "vpn_port" {
  type = string
}

variable "public_key_path" {
  type = string
  default = "~/.ssh/id_azure.pub"
}
