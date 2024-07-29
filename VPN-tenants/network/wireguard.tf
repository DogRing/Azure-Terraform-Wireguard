# key generate 
resource "random_string" "key" {
  length = 8
  upper = true
  lower = true
  special = false
}
locals {
  key_name = var.key_gen == "" ? random_string.key.result : var.key_gen
}
resource "null_resource" "generate_public" {
  count = var.private_key != "" ? 1 : 0
  provisioner "local-exec" {
    command = "echo ${var.private_key} | wg pubkey > ${path.module}/keys/${local.key_name}-public.key"
  }
  triggers = { always_run = "${timestamp()}"}
}

# key generate both
resource "null_resource" "generate_keys" {
  count = var.key_gen != "" ? 1 : 0
  provisioner "local-exec" {
    command = "wg genkey | tee ${path.module}/keys/${var.key_gen}-private.key | wg pubkey > ${path.module}/keys/${var.key_gen}-public.key"
  }
  triggers = { always_run = "${timestamp()}"}
}
data "local_file" "private_key" {
  count = var.key_gen != "" ? 1 : 0
  depends_on = [ null_resource.generate_keys ]
  filename = "${path.module}/keys/${var.key_gen}-private.key"
}
data "local_file" "public_key" {
  depends_on = [ null_resource.generate_keys, null_resource.generate_public ]
  filename = "${path.module}/keys/${local.key_name}-public.key"
}