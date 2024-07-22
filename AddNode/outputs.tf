output "pip" {
  value = azurerm_public_ip.main.*.ip_address
}

output "pri-ip"{
  value = azurerm_network_interface.main.*.private_ip_address
}