module "network" {
  source = "./network"

  # OCI Config
  compartment_id = var.compartment_id
  region         = var.region

  # Project
  project_name = var.project_name

  # VPN VCN Reference
  vpn_vcn_id = var.vpn_vcn_id

  # Node Network
  node_subnet_cidr = var.node_subnet_cidr

  # VPN Server Configuration
  vpn_server_private_ip = var.vpn_server_private_ip
  vpn_subnet_cidr       = var.vpn_subnet_cidr
  vpn_client_cidr       = var.vpn_client_cidr

  # Route Configuration
  route_cidrs = var.route_cidrs
}
