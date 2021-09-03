# Linux VM Input Variables Placeholder file.
variable "web_linuxvm_size" {
  description = "Web Linux VM Size"
  type = string 
  default = "Standard_DS1_v2"
}

variable "web_linuxvm_admin_user" {
  description = "Web Linux VM Admin Username"
  type = string 
  default = "azureuser"
}