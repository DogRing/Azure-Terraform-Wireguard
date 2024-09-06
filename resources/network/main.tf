terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Node network
resource "azurerm_resource_group" "main" {
  name = "rg-${var.project_name}"
  location = var.location
}
resource "azurerm_virtual_network" "main" {
  name = "vnet-${var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space = [ var.address_space ]
}
resource "azurerm_subnet" "main" {
  name = "subnet-${var.project_name}"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [ var.subnet_addresses ]
}

# vNet Peering
resource "azurerm_virtual_network_peering" "VPN-to-Node" {
  name = "peer-${var.project_name}-node"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  remote_virtual_network_id = data.azurerm_virtual_network.vpn.id
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "Node-to-VPN" {
  name = "peer-${var.project_name}-vpn"
  resource_group_name = data.azurerm_resource_group.vpn.name
  virtual_network_name = data.azurerm_virtual_network.vpn.name
  remote_virtual_network_id = azurerm_virtual_network.main.id
  allow_virtual_network_access = true
}

# Route table
resource "azurerm_route_table" "main" {
  name = "routetable-${var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_subnet_route_table_association" "main" {
  subnet_id = azurerm_subnet.main.id
  route_table_id = azurerm_route_table.main.id
}

resource "azurerm_route" "vpn-client" {
  count = length(var.route_addresses)
  name = "route-${var.project_name}-vpn-client-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  route_table_name = azurerm_route_table.main.name
  address_prefix = var.route_addresses[count.index]
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_network_interface.vpn.private_ip_address
}

resource "azurerm_subnet_network_security_group_association" "name" {
  subnet_id = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_security_group" "main" {
  name = "nsg-${var.project_name}"
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
}
