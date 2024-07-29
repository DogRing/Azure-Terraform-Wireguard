terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  backend "azurerm" {}
}

# providers config
provider "azurerm" {
  alias           = "k8s"
  subscription_id = var.tenants.k8s.subscription_id
  tenant_id       = var.tenants.k8s.tenant_id
  client_id       = var.tenants.k8s.client_id
  client_secret   = var.tenants.k8s.client_secret
  features {}
}
provider "azurerm" {
  alias           = "gpu"
  subscription_id = var.tenants.gpu.subscription_id
  tenant_id       = var.tenants.gpu.tenant_id
  client_id       = var.tenants.gpu.client_id
  client_secret   = var.tenants.gpu.client_secret
  features {}
}

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
  enable-ssh  = var.ssh-ips
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
  enable-ssh  = var.ssh-ips
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