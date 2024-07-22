output "pip" {
  value = azurerm_public_ip.main.ip_address
}

locals {
  current_time = timestamp()
}

output "current_time" {
  value = local.current_time
  description = "Current TUC time"
}