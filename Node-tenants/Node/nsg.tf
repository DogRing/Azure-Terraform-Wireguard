resource "azurerm_subnet_network_security_group_association" "name" {
  count = length(azurerm_subnet.main)
  subnet_id = azurerm_subnet.main[count.index].id
  network_security_group_id = azurerm_network_security_group.main[count.index].id
}

resource "azurerm_network_security_group" "main" {
  count = length(azurerm_subnet.main)
  name = "nsg-${var.project_name}-${count.index}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "vpn" {
  count = length(azurerm_subnet.main)
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main[count.index].name

  name = "Allow-VPN"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "10.255.255.0/24"
  destination_address_prefix = "*"
}


resource "azurerm_network_security_rule" "internal" {
  count = length(azurerm_subnet.main)
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main[count.index].name

  name = "Allow-internal"
  priority = 101
  direction = "Inbound"
  access = "Allow"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "10.244.0.0/16"
  destination_address_prefix = "*"
}
