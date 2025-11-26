module "network" {
  source = "./network"

  # OCI Config
  compartment_id = var.compartment_id
  region         = var.region

  # Project
  project_name = var.project_name

  # Network
  vcn_cidr          = var.vcn_cidr
  vpn_subnet_cidr   = var.vpn_subnet_cidr
  vm_private_ip     = var.vm_private_ip

  # Security
  vpn_port   = var.vpn_port
  enable_ssh = var.enable_ssh

  # Remote Networks
  remote_networks = var.remote_networks

  # Wireguard Key
  private_key = var.private_key
  key_gen     = var.key_gen
}

module "wireguard" {
  source = "./wireguard"

  # Project
  project_name = var.project_name

  # Network
  network = module.network

  # VM Configuration
  vm_shape               = var.vm_shape
  vm_ocpus               = var.vm_ocpus
  vm_memory_in_gbs       = var.vm_memory_in_gbs
  boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  ssh_public_key_path    = var.ssh_public_key_path
  vm_username            = var.vm_username

  # Image
  compartment_id           = var.compartment_id
  operating_system         = var.operating_system
  operating_system_version = var.operating_system_version

  # Wireguard Peers
  wg_peers = var.wg_peers
}
