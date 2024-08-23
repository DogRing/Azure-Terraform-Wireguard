resource "azurerm_storage_account" "main" {
  name = "changhsafiles"
  resource_group_name = data.azurerm_resource_group.vpn.name
  location = data.azurerm_resource_group.vpn.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "main" {
  name = "azdata"
  storage_account_name = azurerm_storage_account.main.name
  quota = 100
}

resource "azurerm_private_endpoint" "main" {
  name = "azdata-endpoint"
  resource_group_name = data.azurerm_resource_group.vpn.name
  location = data.azurerm_resource_group.vpn.location
  subnet_id = data.azurerm_subnet.vpn.id

  
  private_service_connection {
    name = "azdata-conn"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection = false
    subresource_names = ["file"]
  }
}
