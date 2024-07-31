locals {
  peer_string = <<EOF
%{ for peer in var.wg_peers }
[Peer]
PublicKey = ${peer.public_key}
EndPoint = ${peer.endpoint}
AllowedIPs = ${peer.allowed_ips}
%{ endfor }
EOF
}
data "template_file" "userdata" {
  template = file("${path.module}/userdata.tpl")
  vars = {
    vpn_server_ip      = var.network.vpn_interface_ip
    vpn_port           = var.network.vpn_port
    server_private_key = var.network.vpn_private_key
    wg_peers           = local.peer_string
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "vm-${var.project_name}"
  resource_group_name   = var.network.resource_group_name
  location              = var.network.location
  size                  = var.vm_data.vm_size
  admin_username        = var.vm_data.username
  network_interface_ids = [ var.network.nic-id ]

  admin_ssh_key {
    username   = var.vm_data.username
    public_key = file(var.vm_data.public_key_path)
  }

  os_disk {
    name                 = "osdisk-${var.project_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_data.image_publisher
    offer     = var.vm_data.image_offer
    sku       = var.vm_data.image_sku
    version   = var.vm_data.image_version
  }

  custom_data = base64encode(data.template_file.userdata.rendered)
}