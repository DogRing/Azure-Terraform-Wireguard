# network module
module "network-k8s" {
  source       = "./network"
  providers    = { azurerm = azurerm.k8s }
  project_name = "VPN"
  location     = "koreacentral"

  vnet_address_space    = "192.168.255.0/24"
  subnet_address_prefix = "192.168.255.0/25"
  vm_private_ip         = "192.168.255.4"
  vpn_interface_ip      = "192.168.255.128/25"
  allowed_ips           = "192.168.1.0/24"

  # vnet_address_space    = "10.255.0.0/16"
  # subnet_address_prefix = "10.255.255.0/25"
  # vm_private_ip         = "10.255.255.4"
  # vpn_interface_ip      = "10.255.255.128/25"
  # allowed_ips           = "10.10.0.0/16"

  private_key = var.private_key_k8s
  vpn_port    = var.vpn_port
  # enable-ssh  = var.ssh-ips
  enable-igw  = true
}
module "network-gpu" {
  source       = "./network"
  providers    = { azurerm = azurerm.gpu }
  project_name = "VPN"
  location     = "koreacentral"

  vnet_address_space    = "192.168.255.0/24"
  subnet_address_prefix = "192.168.255.0/25"
  vm_private_ip         = "192.168.255.4"
  vpn_interface_ip      = "192.168.255.130/25"
  allowed_ips           = "192.168.3.0/24, 192.168.4.0/24"

  # vnet_address_space    = "10.255.0.0/16"
  # subnet_address_prefix = "10.255.255.0/25"
  # vm_private_ip         = "10.255.255.6"
  # vpn_interface_ip      = "10.255.255.130/25"
  # allowed_ips           = "10.20.0.0/16"

  private_key = var.private_key_gpu
  vpn_port    = var.vpn_port
  # enable-ssh  = var.ssh-ips
  enable-igw  = true
}


module "az1" {
  source       = "./wireguard"
  providers    = { azurerm = azurerm.k8s }
  project_name = "VPN"
  network      = module.network-k8s


  route_address_prefix = ["192.168.0.0/24", "192.168.3.0/24", "192.168.255.128/25", "192.168.4.0/24"]
  vm_data              = var.vm_data
  wg_peers             = [jsondecode(module.network-gpu.wg-peer), var.on_prem_k8s_peer]
}
module "az2" {
  source       = "./wireguard"
  providers    = { azurerm = azurerm.gpu }
  project_name = "VPN"
  network = module.network-gpu

  route_address_prefix = ["192.168.0.0/24", "192.168.1.0/24", "192.168.255.128/25"]
  vm_data              = var.vm_data
  wg_peers             = [jsondecode(module.network-k8s.wg-peer), var.on_prem_gpu_peer]
}