variable "project_name" { type = string }
variable "tenants" { type = map(map(string)) }

variable "vpn_port" { type = string }
variable "ssh-ips" { type = list(string) }
variable "vm_data" { type = map(string) }

variable "on_prem_k8s_peer" { type = map(string) }
variable "on_prem_gpu_peer" { type = map(string) }

# You can replace key_gen = "key_name"
variable "private_key_k8s" { type = string }
variable "private_key_gpu" { type = string }