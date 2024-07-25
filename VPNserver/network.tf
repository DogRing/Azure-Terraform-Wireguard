resource "azurerm_resource_group" "main" {
  name     = "rg-${local.az_var.project_name}"
  location = local.az_var.location
}

resource "azurerm_virtual_network" "main" {
  name = "vnet-${local.az_var.project_name}"
  address_space = [local.az_var.vnet_address_space]
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name = "subnet-${local.az_var.project_name}"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [local.az_var.subnet_address_space]
}

resource "azurerm_public_ip" "main" {
  name = "pip-${local.az_var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method = "Static"
}

resource "azurerm_network_interface" "main" {
  name = "nic-${local.az_var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  enable_ip_forwarding = true

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address = local.az_var.vm_private_ip
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_security_group" "main" {
  name = "nsg-${local.az_var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name = "WireGuard-Inbound"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Udp"
    source_port_range = "*"
    destination_port_ranges = [local.az_var.vpn_port]
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name = "SSH-Inbound"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_ranges = ["22"]
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_route_table" "main" {
  name = "rt-${local.az_var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_route" "vpn" {
  name = "route-${local.az_var.project_name}-vpn"
  resource_group_name = azurerm_resource_group.main.name
  route_table_name = azurerm_route_table.main.name
  address_prefix = var.onprem_address_prefix
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_network_interface.main.private_ip_address
}

resource "azurerm_route" "vpn-client" {
  name = "route-${local.az_var.project_name}-vpn-client"
  resource_group_name = azurerm_resource_group.main.name
  route_table_name = azurerm_route_table.main.name
  address_prefix = var.vpn_client_address_prefix
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_network_interface.main.private_ip_address
}
resource "azurerm_route" "IGW" {
  name = "route-${local.az_var.project_name}-igw"
  resource_group_name = azurerm_resource_group.main.name
  route_table_name = azurerm_route_table.main.name
  address_prefix = "0.0.0.0/0"
  next_hop_type = "Internet"
}

resource "azurerm_subnet_route_table_association" "main" {
  subnet_id = azurerm_subnet.main.id
  route_table_id = azurerm_route_table.main.id
}