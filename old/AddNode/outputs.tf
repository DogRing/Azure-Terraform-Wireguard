output "pri-ip"{
  value = azurerm_network_interface.main.*.private_ip_address
}

locals { current_time = timeadd(timestamp(),"9h") }
output "current_time" {
  value       = local.current_time
  description = "Current TUC time"
}