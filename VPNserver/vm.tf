data "template_file" "userdata" {
  template = file("userdata.tpl")
  vars = {
    server_ip = azurerm_public_ip.main.ip_address
    vpn_port = var.vpn_port
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name = "${var.project_name}vm"
  resource_group_name = azurerm_resource_group.main.name
  location = azurerm_resource_group.main.location
  size = "Standard_B1ms"
  admin_username = "dogring232"
  network_interface_ids = [ azurerm_network_interface.main.id ]

  admin_ssh_key {
    username = "dogring232"
    public_key = file(var.public_key_path)
  }

  os_disk {
    name = "${var.project_name}os"
    caching           = "ReadWrite"
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