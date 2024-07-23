data "external" "microk8sAddNode" {
  program = ["bash", "${path.module}/get_node_config.sh"]
}

data "template_file" "userdata" {
  template = file("userdata.tpl")
  vars = {
    vpn_ip = data.azurerm_network_interface.vpn.private_ip_address
    microk8sAddNode = data.external.microk8sAddNode.result.output
    username = var.username
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  count = var.node_count

  name = "vm-${var.project_name}-${count.index}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  network_interface_ids = [ azurerm_network_interface.main[count.index].id ]
  size = var.vm_image
  admin_username = data.template_file.userdata.vars.username

  admin_ssh_key {
    username = data.template_file.userdata.vars.username
    public_key = file(var.public_key_path)
  }

  os_disk {
    name = "OsDisk-${var.project_name}-${count.index}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    when = destroy
    command = "microk8s remove-node ${self.private_ip_address} --force"
  }
  custom_data = base64encode(data.template_file.userdata.rendered)
}

resource "azurerm_network_interface" "main" {
  count = var.node_count
  name = "nic-${var.project_name}-${count.index}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name 

  ip_configuration {
    name = "nic-config-${var.project_name}-${count.index}"
    subnet_id = azurerm_subnet.main[count.index % length(azurerm_subnet.main)].id
    private_ip_address_allocation = "Dynamic"
  }
}