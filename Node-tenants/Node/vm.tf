data "external" "microk8sAddNode" {
  count = var.node_count
  program = ["bash", "${path.module}/get_node_config.sh"]
}

data "template_file" "userdata" {
  count = var.node_count
  template = file(var.vm_config.template_file)
  vars = {
    vpn_ip = data.azurerm_network_interface.vpn.private_ip_address
    microk8sAddNode = data.external.microk8sAddNode[count.index].result.output
    node_name = lower("vm-${var.project_name}-${count.index}")
    node_ip = azurerm_network_interface.main[count.index].private_ip_address
    username = var.vm_config.vm_name
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  count = var.node_count

  name = "vm-${var.vm_config.vm_name}-${count.index}"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  network_interface_ids = [ azurerm_network_interface.main[count.index].id ]
  size = var.vm_config.vm_spec
  admin_username = var.vm_config.vm_name

  admin_ssh_key {
    username = var.vm_config.vm_name
    public_key = file(var.vm_config.public_key_path)
  }

  os_disk {
    name = "osDisk-${var.project_name}-${count.index}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_config.publisher
    offer     = var.vm_config.offer
    sku       = var.vm_config.sku
    version   = var.vm_config.version
  }

  provisioner "local-exec" {
    when = destroy
    command = "microk8s remove-node ${self.private_ip_address} --force"
    on_failure = "continue"
  }
  custom_data = base64encode(data.template_file.userdata[count.index].rendered)
}

resource "azurerm_virtual_machine_extension" "nvidia" {
  count = var.gpu == true ? length(var.node_count) : 0
  name = "gpu-driver-extension"
  virtual_machine_id = azurerm_linux_virtual_machine.main[count.index].id
  publisher = "Microsoft.HpcCompute"
  type = "NvidiaGpuDriverLinux"
  type_handler_version = "1.9"
  auto_upgrade_minor_version = true
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