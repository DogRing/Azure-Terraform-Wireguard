variable "project_name" { type = string }
# { name = {subscription_id, tenant_id, client_id, client_secret} } 
variable "tenants" { type = map(map(string)) }

variable "vpn_port" { type = string }
variable "ssh-ips" { type = list(string) }
# { username, vm_size, public_key_path, image_publisher, image_offer, image_sku, image_version } 
variable "vm_data" { type = map(string) }

# { endpoint, public_key, allowed_ips }
variable "on_prem_k8s_peer" { type = map(string) }
variable "on_prem_gpu_peer" { type = map(string) }

# You can replace key_gen = "key_name"
variable "private_key_k8s" { type = string }
variable "private_key_gpu" { type = string }