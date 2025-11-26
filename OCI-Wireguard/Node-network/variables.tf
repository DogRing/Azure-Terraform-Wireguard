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

## VPN VCN Reference (existing VCN created by VPN-server)
variable "vpn_vcn_id" {
  description = "VPN VCN OCID (from VPN-server output)"
  type        = string
}

## Node Network Configuration
variable "node_subnet_cidr" {
  description = "Node subnet CIDR block (within VPN VCN)"
  type        = string
  default     = "10.255.1.0/24"
}

## VPN Server Configuration (for routing)
variable "vpn_server_private_ip" {
  description = "VPN server private IP address"
  type        = string
  default     = "10.255.255.10"
}

## VPN Configuration (for security rules)
variable "vpn_subnet_cidr" {
  description = "VPN server subnet CIDR (for security rules)"
  type        = string
  default     = "10.255.255.0/24"
}

variable "vpn_client_cidr" {
  description = "VPN client CIDR block (for security rules)"
  type        = string
  default     = "192.168.255.0/24"
}

## Route Configuration
variable "route_cidrs" {
  description = "CIDR blocks to route through VPN (VPN clients that should access this subnet)"
  type        = list(string)
  default = [
    "192.168.255.0/24",    # VPN clients
    "192.168.0.0/24",      # Additional networks
    "192.168.1.0/24",
    "192.168.3.0/24"
  ]
}
