# VPN Network
data "azurerm_resource_group" "vpn" {
    name = var.vpn_config.resource_group_name
}
data "azurerm_virtual_network" "vpn" {
  name = var.vpn_config.virtual_network_name
  resource_group_name = data.azurerm_resource_group.vpn.name
}
data "azurerm_subnet" "vpn" {
  name = var.vpn_config.subnet_name
  resource_group_name = data.azurerm_resource_group.vpn.name
  virtual_network_name = data.azurerm_virtual_network.vpn.name
}
data "azurerm_network_interface" "vpn" {
  name = var.vpn_config.vpn_nic_name
  resource_group_name = data.azurerm_resource_group.vpn.name
}
