# network module
module "network-k8s" {
  source       = "./network"
  providers    = { azurerm = azurerm.k8s }
  project_name = "VPN"
  location     = "koreacentral"

  vnet_address_space    = "10.255.0.0/16"
  subnet_address_prefix = "10.255.255.0/25"
  vm_private_ip         = "10.255.255.4"
  vpn_interface_ip      = "10.255.255.128/25"
  allowed_ips           = "10.10.0.0/16"

  private_key = var.private_key_k8s
  vpn_port    = var.vpn_port
  enable-igw  = true
}
module "network-gpu" {
  source       = "./network"
  providers    = { azurerm = azurerm.gpu }
  project_name = "VPN"
  location     = "koreacentral"

  vnet_address_space    = "10.255.0.0/16"
  subnet_address_prefix = "10.255.255.0/25"
  vm_private_ip         = "10.255.255.6"
  vpn_interface_ip      = "10.255.255.130/25"
  allowed_ips           = "10.20.0.0/16"

  private_key = var.private_key_gpu
  vpn_port    = var.vpn_port
  enable-igw  = true
}


module "wireguard-k8s" {
  source       = "./wireguard"
  providers    = { azurerm = azurerm.k8s }
  project_name = "VPN"
  network      = module.network-k8s

  vm_data = var.vm_data

  route_address_prefix = ["192.168.0.0/16", "10.20.0.0/16", "10.255.255.128/25"]
  wg_peers             = [jsondecode(module.network-gpu.wg-peer), var.on_prem_k8s_peer]
}
module "wireguard-gpu" {
  source       = "./wireguard"
  providers    = { azurerm = azurerm.gpu }
  project_name = "VPN"

  network = module.network-gpu
  vm_data = var.vm_data

  route_address_prefix = ["192.168.0.0/16", "10.10.0.0/16", "10.255.255.128/25"]
  wg_peers             = [jsondecode(module.network-k8s.wg-peer), var.on_prem_gpu_peer]
}