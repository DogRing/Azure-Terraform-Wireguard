output "az1-ip"{
  value = module.az1.pri-ip
}
output "az2-ip"{
  value = module.az2.pri-ip
}
locals { current_time = timeadd(timestamp(),"9h") }
output "current_time" {
  value       = local.current_time
  description = "Current TUC time"
}