output "pri-ip"{
  value = azurerm_network_interface.main.*.private_ip_address
}

locals { current_time = timestamp() }
output "current_time" {
  value       = local.current_time
  description = "Current TUC time"
}