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