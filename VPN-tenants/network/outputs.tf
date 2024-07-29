output "resource_group_name" { value = azurerm_resource_group.main.name }
output "location" { value = azurerm_resource_group.main.location }
output "route_table_name" { value = azurerm_route_table.main.name }
output "nic-id" { value = azurerm_network_interface.main.id }
output "nic-address" { value = azurerm_network_interface.main.private_ip_address }

output "vpn_interface_ip" { value = var.vpn_interface_ip }
output "vpn_private_key" { 
  value = length(var.key_gen) > 0 ? trimspace(data.local_file.private_key[0].content) : var.private_key
}
output "vpn_port" { value = var.vpn_port}

output "wg-peer" {
  value = jsonencode({
    public_key  = trimspace(data.local_file.public_key.content)
    endpoint    = "${azurerm_public_ip.main.ip_address}:${var.vpn_port}"
    allowed_ips = "${var.allowed_ips}, ${var.vpn_interface_ip}"
  })
}

output "pip" { value = azurerm_public_ip.main.ip_address}