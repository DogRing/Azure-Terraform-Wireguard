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
  subscription_id = var.tenants.gpu.subscription_id
  tenant_id       = var.tenants.gpu.tenant_id
  client_id       = var.tenants.gpu.client_id
  client_secret   = var.tenants.gpu.client_secret
  features {}
}