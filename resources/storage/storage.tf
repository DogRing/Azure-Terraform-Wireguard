resource "azurerm_storage_account" "main" {
  name = var.storage_name
  resource_group_name = var.network.resource_group_name
  location = var.network.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "main" {
  name = var.files_path
  storage_account_name = azurerm_storage_account.main.name
  quota = var.quota
}

resource "azurerm_private_endpoint" "main" {
  name = "${var.files_path}-endpoint"
  resource_group_name = var.network.resource_group_name
  location = var.network.location
  subnet_id = var.network.subnet_id

  private_service_connection {
    name = "${var.files_path}-conn"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection = false
    subresource_names = ["file"]
  }
}
