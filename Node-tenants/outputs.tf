output "pri-ip"{
  value = module.Node-gpu.pri-ip
}

locals { current_time = timeadd(timestamp(),"9h") }
output "current_time" {
  value       = local.current_time
  description = "Current TUC time"
}