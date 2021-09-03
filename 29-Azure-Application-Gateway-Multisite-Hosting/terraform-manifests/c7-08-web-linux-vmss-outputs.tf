# VM Scale Set Outputs

output "app1_web_vmss_id" {
  description = "App1 Web Virtual Machine Scale Set ID"
  value = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id 
}

output "app2_web_vmss_id" {
  description = "App2 Web Virtual Machine Scale Set ID"
  value = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id 
}