# NSG Config
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "WireGuard-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = [ var.vpn_port ]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_security_rule" "enable-ssh" {
  count = length(var.enable-ssh)

  name = "SSH-Inbound-${count.index}"
  priority = 110 + count.index
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_ranges = ["22"]
  source_address_prefix = var.enable-ssh[count.index]
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Route Table Config
resource "azurerm_route_table" "main" {
  name                = "rt-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_route" "IGW" {
  count               = var.enable-igw ? 1 : 0
  name                = "route-${var.project_name}-igw"
  resource_group_name = azurerm_resource_group.main.name
  route_table_name    = azurerm_route_table.main.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}
resource "azurerm_subnet_route_table_association" "main" {
  subnet_id      = azurerm_subnet.main.id
  route_table_id = azurerm_route_table.main.id
}