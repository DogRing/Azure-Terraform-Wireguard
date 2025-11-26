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

variable "vpn_vcn_id" {
  description = "VPN VCN OCID"
  type        = string
}

variable "node_subnet_cidr" {
  description = "Node subnet CIDR block"
  type        = string
}

variable "vpn_server_private_ip" {
  description = "VPN server private IP address"
  type        = string
}

variable "vpn_subnet_cidr" {
  description = "VPN server subnet CIDR"
  type        = string
}

variable "vpn_client_cidr" {
  description = "VPN client CIDR block"
  type        = string
}

variable "route_cidrs" {
  description = "CIDR blocks to route through VPN"
  type        = list(string)
}
