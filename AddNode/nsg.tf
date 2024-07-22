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

  security_rule {
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

  security_rule {
    name = "Allow-SSH-home"
    priority = 102
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "112.168.230.153/32"
    destination_address_prefix = "*"
  }
}
