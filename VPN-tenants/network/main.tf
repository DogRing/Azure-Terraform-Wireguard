resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}"
  location = var.location
}
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}"
  address_space       = [ var.vnet_address_space ]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_subnet" "main" {
  name                 = "subnet-${var.project_name}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [ var.subnet_address_prefix ]
}

# nic, pip Config
resource "azurerm_public_ip" "main" {
  name                = "pip-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}
resource "azurerm_network_interface" "main" {
  name                 = "nic-${var.project_name}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_private_ip
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}
