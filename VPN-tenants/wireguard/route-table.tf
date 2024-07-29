resource "azurerm_route" "vpn" {
  count                  = length(var.route_address_prefix)
  name                   = "route-${var.project_name}-vpn-${count.index}"
  resource_group_name    = var.network.resource_group_name
  route_table_name       = var.network.route_table_name
  address_prefix         = var.route_address_prefix[count.index]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.network.nic-address
}