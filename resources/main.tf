module "network" {
  source = "./network"
  project_name = "resources"
  providers = { azurerm = azurerm }

  location = "koreacentral"
  address_space = "192.168.4.0/24"
  subnet_addresses = "192.168.4.0/24"
  route_addresses = [ "192.168.255.128/25", "192.168.0.0/24", "192.168.1.0/24", "192.168.3.0/24" ]

  vpn_config = var.vpn_config
}

module "storage-gpu" {
  source = "./storage"
  storage_name = "changhsafiles"
  network = module.network
  
  files_path = "azdata"
  quota = 100
}