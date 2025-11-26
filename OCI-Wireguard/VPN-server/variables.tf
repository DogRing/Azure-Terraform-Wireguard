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
  default     = "wireguard-vpn"
}

## Network
variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.255.255.0/24"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "10.255.255.0/24"
}

variable "vm_private_ip" {
  description = "VPN server private IP address"
  type        = string
  default     = "10.255.255.10"
}

variable "vpn_port" {
  description = "Wireguard VPN port"
  type        = string
  default     = "51820"
}

variable "enable_ssh" {
  description = "CIDR blocks allowed for SSH access (empty to disable SSH)"
  type        = list(string)
  default     = []
}

## Wireguard
variable "private_key" {
  description = "Wireguard private key (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "key_gen" {
  description = "Key file name prefix (leave empty to auto-generate)"
  type        = string
  default     = ""
}

variable "wg_peers" {
  description = "Wireguard peer configurations"
  type = list(object({
    public_key  = string
    endpoint    = string
    allowed_ips = string
  }))
  default = []
}

## VM Configuration
variable "vm_shape" {
  description = "Compute instance shape"
  type        = string
  default     = "VM.Standard.E2.1.Micro"  # Always Free eligible
}

variable "vm_ocpus" {
  description = "Number of OCPUs (for Flex shapes)"
  type        = number
  default     = 1
}

variable "vm_memory_in_gbs" {
  description = "Amount of memory in GBs (for Flex shapes)"
  type        = number
  default     = 6
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GBs"
  type        = number
  default     = 50
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_username" {
  description = "VM admin username"
  type        = string
  default     = "ubuntu"
}

variable "operating_system" {
  description = "Operating System"
  type        = string
  default     = "Canonical Ubuntu"
}

variable "operating_system_version" {
  description = "Operating System Version"
  type        = string
  default     = "22.04"
}
