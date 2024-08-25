output "resource_group_name" { value = azurerm_resource_group.main.name }
output "location" { value = azurerm_resource_group.main.location }
output "subnet_id" { value = azurerm_subnet.main.id }