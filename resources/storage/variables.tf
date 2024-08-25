variable "storage_name" { type = string }
variable "network" { type = map(string) }

variable "files_path" { type = string }
variable "quota" { 
    type = number
    default = 50
}