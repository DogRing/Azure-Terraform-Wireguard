data "template_file" "userdata" {
  template = file("userdata.tpl")
  vars = {
    server_ip          = azurerm_public_ip.main.ip_address
    vpn_server_ip      = local.az_var.vpn_server_ip
    vpn_peer_ip        = local.az_var.vpn_peer_ip
    server_private_key = local.az_var.server_private_key
    client_public_key  = local.az_var.client_public_key
    vpn_port           = local.az_var.vpn_port
    vm_private_ip      = local.az_var.vm_private_ip

    onprem_address_prefix     = var.onprem_address_prefix
    vpn_client_address_prefix = var.vpn_client_address_prefix
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "vm-${var.project_name}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = var.vm_size
  admin_username        = var.username
  network_interface_ids = [azurerm_network_interface.main.id]

  admin_ssh_key {
    username   = var.username
    public_key = file(var.public_key_path)
  }

  os_disk {
    name                 = "osdisk-${var.project_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(data.template_file.userdata.rendered)
}