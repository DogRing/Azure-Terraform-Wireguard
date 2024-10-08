# Node network
resource "azurerm_resource_group" "main" {
  name = local.az_var.resource_group_name
  location = local.az_var.location
}
resource "azurerm_virtual_network" "main" {
  name = "vnet-${var.project_name}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space = [local.az_var.node_vnet_address]
}
resource "azurerm_subnet" "main" {
  count = length(split(",",local.az_var.subnet_addresses))
  name = "subnet-${var.project_name}-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = [split(",",local.az_var.subnet_addresses)[count.index]]
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

# NAT gateway
resource "azurerm_nat_gateway" "main" {
  count = length(azurerm_subnet.main)
  name = "nat-${var.project_name}-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
}
resource "azurerm_public_ip" "main" {
  count = length(azurerm_nat_gateway.main)
  name = "pip-${var.project_name}-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
  allocation_method = "Static"
  sku = "Standard"
}
resource "azurerm_nat_gateway_public_ip_association" "main" {
  count = length(azurerm_subnet.main)
  nat_gateway_id = azurerm_nat_gateway.main[count.index].id
  public_ip_address_id = azurerm_public_ip.main[count.index].id
}
resource "azurerm_subnet_nat_gateway_association" "main" {
  count = length(azurerm_subnet.main)
  subnet_id = azurerm_subnet.main[count.index].id
  nat_gateway_id = azurerm_nat_gateway.main[count.index].id
}

# Route table
resource "azurerm_route_table" "main" {
  count = length(azurerm_subnet.main)
  name = "routetable-${var.project_name}-${count.index}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_subnet_route_table_association" "main" {
  count = length(azurerm_route_table.main)
  subnet_id = azurerm_subnet.main[count.index].id
  route_table_id = azurerm_route_table.main[count.index].id
}

resource "azurerm_route" "vpn-client" {
  count = (length(azurerm_route_table.main) * length(local.az_route_addresses))
  name = "route-${var.project_name}-vpn-client-${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  route_table_name = azurerm_route_table.main[floor(count.index / length(local.az_route_addresses))].name
  address_prefix = local.az_route_addresses[floor(count.index % length(local.az_route_addresses))]
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_network_interface.vpn.private_ip_address
}
