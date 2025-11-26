variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "network" {
  description = "Network module outputs"
  type = object({
    compartment_id  = string
    region          = string
    subnet_id       = string
    nsg_id          = string
    vpn_private_ip  = string
    vpn_port        = string
    vpn_public_key  = string
    vpn_private_key = string
  })
}

variable "vm_shape" {
  description = "Compute instance shape"
  type        = string
}

variable "vm_ocpus" {
  description = "Number of OCPUs (for Flex shapes)"
  type        = number
}

variable "vm_memory_in_gbs" {
  description = "Amount of memory in GBs (for Flex shapes)"
  type        = number
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GBs"
  type        = number
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "vm_username" {
  description = "VM admin username"
  type        = string
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "operating_system" {
  description = "Operating System"
  type        = string
}

variable "operating_system_version" {
  description = "Operating System Version"
  type        = string
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
