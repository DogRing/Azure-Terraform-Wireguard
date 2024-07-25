terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = local.az_tenant.subscription_id
  tenant_id = local.az_tenant.tenant_id
  client_id = local.az_tenant.client_id
  client_secret = local.az_tenant.client_secret

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  az_tenant = terraform.workspace == "gpu" ? var.gpu_tenant : var.default_tenant
  az_var = terraform.workspace == "gpu" ? var.gpu_variables : var.default_variables
}