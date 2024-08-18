module "Node-k8s" {
  project_name = var.tf_config.k8s.project_name
  source = "./Node"
  providers = { azurerm = azurerm.k8s }
  node_count = var.tf_config.k8s.node_count

  location = var.tf_config.k8s.location
  address_space = "192.168.1.0/24"
  subnet_addresses = ["192.168.1.0/24"]
  route_addresses = [ "192.168.255.128/25", "192.168.0.0/24", "192.168.3.0/24" ]

  # microk8s = true
  vpn_config = var.vpn_config
  vm_config = var.vm_config.k8s
  hosts = var.etc_hosts.k8s
}

module "Node-gpu" {
  project_name = var.tf_config.gpu.project_name
  source = "./Node"
  providers = { azurerm = azurerm.gpu }
  node_count = var.tf_config.gpu.node_count

  location = var.tf_config.gpu.location
  address_space = "192.168.3.0/24"
  subnet_addresses = ["192.168.3.0/24"]
  route_addresses = [ "192.168.255.128/25", "192.168.0.0/24", "192.168.1.0/24" ]

  # microk8s = true
  vpn_config = var.vpn_config
  vm_config = var.vm_config.gpu
  hosts = var.etc_hosts.gpu
}