output "stroage-gpu-endpoint" {
  value = module.storage-gpu.private_endpoint
}

output "storage-gpu-key" {
  value = module.storage-gpu.storage_account_key
  sensitive = true
}