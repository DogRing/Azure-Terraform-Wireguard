## OCI Authentication
variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI API private key"
  type        = string
}

variable "region" {
  description = "OCI Region (e.g., ap-seoul-1, ap-chuncheon-1)"
  type        = string
  default     = "ap-seoul-1"
}

## Compartment
variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

## Project
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "node-network"
}

## Network
variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "192.168.4.0/24"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "192.168.4.0/24"
}

## VPN Configuration
variable "vpn_config" {
  description = "VPN network configuration"
  type = object({
    compartment_id = string
    vcn_id         = string
    subnet_id      = string
    private_ip     = string
  })
}

## Route Configuration
variable "route_cidrs" {
  description = "CIDR blocks to route through VPN"
  type        = list(string)
  default = [
    "192.168.255.128/25",
    "192.168.0.0/24",
    "192.168.1.0/24",
    "192.168.3.0/24"
  ]
}

## VPN Client CIDR (for security rules)
variable "vpn_client_cidr" {
  description = "VPN client CIDR block"
  type        = string
  default     = "10.255.255.0/24"
}
