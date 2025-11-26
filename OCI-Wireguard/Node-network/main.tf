module "network" {
  source = "./network"

  # OCI Config
  compartment_id = var.compartment_id
  region         = var.region

  # Project
  project_name = var.project_name

  # Network
  vcn_cidr    = var.vcn_cidr
  subnet_cidr = var.subnet_cidr

  # VPN Configuration
  vpn_config = var.vpn_config

  # Route Configuration
  route_cidrs      = var.route_cidrs
  vpn_client_cidr  = var.vpn_client_cidr
}
