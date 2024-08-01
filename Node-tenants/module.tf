module "Node-k8s" {
  project_name = "k8snode"
  source = "./Node"
  providers = { azurerm = azurerm.k8s }
  node_count = 1

  location = "koreacentral"
  address_space = "10.10.0.0/16"
  subnet_addresses = ["10.10.1.0/24"]
  route_addresses = [ "10.255.255.128/25", "192.168.0.0/24", "10.20.0.0/16" ]

  vpn_config = var.vpn_config
  vm_config = var.vm_config.k8s
}

module "Node-gpu" {
  project_name = "gpunode"
  source = "./Node"
  providers = { azurerm = azurerm.gpu }
  node_count = 1

  location = "koreacentral"
  address_space = "10.20.0.0/16"
  subnet_addresses = ["10.20.1.0/24"]
  route_addresses = [ "10.255.255.128/25", "192.168.0.0/24", "10.10.0.0/16" ]

  vpn_config = var.vpn_config
  vm_config = var.vm_config.k8s
}