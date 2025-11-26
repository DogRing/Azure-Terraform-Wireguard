variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "region" {
  description = "OCI Region"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
}

variable "vm_private_ip" {
  description = "VPN server private IP address"
  type        = string
}

variable "vpn_port" {
  description = "Wireguard VPN port"
  type        = string
}

variable "enable_ssh" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "private_key" {
  description = "Wireguard private key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "key_gen" {
  description = "Key file name prefix"
  type        = string
  default     = ""
}
