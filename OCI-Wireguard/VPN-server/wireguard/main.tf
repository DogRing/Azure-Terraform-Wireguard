terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Get Ubuntu images
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = var.operating_system
  operating_system_version = var.operating_system_version
  shape                    = var.vm_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Wireguard Peers configuration
locals {
  peer_string = <<EOF
%{for peer in var.wg_peers}
[Peer]
PublicKey = ${peer.public_key}
EndPoint = ${peer.endpoint}
AllowedIPs = ${peer.allowed_ips}
%{endfor}
EOF
}

# Cloud-init userdata
data "template_file" "userdata" {
  template = file("${path.module}/userdata.tpl")
  vars = {
    vpn_server_ip      = var.network.vpn_private_ip
    vpn_port           = var.network.vpn_port
    server_private_key = var.network.vpn_private_key
    wg_peers           = local.peer_string
  }
}

# Compute Instance
resource "oci_core_instance" "main" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  shape               = var.vm_shape
  display_name        = "vm-${var.project_name}"

  # Shape configuration (for Flex shapes)
  dynamic "shape_config" {
    for_each = length(regexall(".*Flex$", var.vm_shape)) > 0 ? [1] : []
    content {
      ocpus         = var.vm_ocpus
      memory_in_gbs = var.vm_memory_in_gbs
    }
  }

  # Boot volume
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  # Primary VNIC
  create_vnic_details {
    subnet_id              = var.network.subnet_id
    display_name           = "vnic-${var.project_name}"
    assign_public_ip       = true
    private_ip             = var.network.vpn_private_ip
    skip_source_dest_check = true  # Enable IP forwarding for Wireguard
    nsg_ids                = [var.network.nsg_id]
  }

  # SSH key and cloud-init
  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data           = base64encode(data.template_file.userdata.rendered)
  }

  preserve_boot_volume = false

  # Ignore changes to user_data to prevent VM recreation
  lifecycle {
    ignore_changes = [
      metadata["user_data"],  # Ignore userdata changes
    ]
  }
}

# Get instance's public IP
data "oci_core_vnic_attachments" "instance_vnics" {
  compartment_id      = var.compartment_id
  instance_id         = oci_core_instance.main.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

data "oci_core_vnic" "instance_vnic" {
  vnic_id = data.oci_core_vnic_attachments.instance_vnics.vnic_attachments[0].vnic_id
}
