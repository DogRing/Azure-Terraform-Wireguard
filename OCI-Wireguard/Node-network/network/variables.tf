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

variable "vpn_config" {
  description = "VPN network configuration"
  type = object({
    compartment_id = string
    vcn_id         = string
    subnet_id      = string
    private_ip     = string
  })
}

variable "route_cidrs" {
  description = "CIDR blocks to route through VPN"
  type        = list(string)
}

variable "vpn_client_cidr" {
  description = "VPN client CIDR block"
  type        = string
}
