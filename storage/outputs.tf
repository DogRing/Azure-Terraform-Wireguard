output "private_endpoint" {
  value = azurerm_private_endpoint.main.private_service_connection[0].private_ip_address
}

output "storage_account_key" {
  value = azurerm_storage_account.main.primary_access_key
  sensitive = true
}