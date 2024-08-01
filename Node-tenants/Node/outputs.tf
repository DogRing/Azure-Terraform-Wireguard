output "pri-ip"{
  value = azurerm_network_interface.main.*.private_ip_address
}