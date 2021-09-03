# Linux VM Input Variables Placeholder file.
variable "app1_web_vmss_nsg_inbound_ports" {
  description = "App1 Web VMSS NSG Inbound Ports"
  type = list(string)
  default = [22, 80, 443]
}

variable "app2_web_vmss_nsg_inbound_ports" {
  description = "App2 Web VMSS NSG Inbound Ports"
  type = list(string)
  default = [22, 80, 443]
}


