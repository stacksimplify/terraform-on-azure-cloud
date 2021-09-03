# Different Outputs with Terraform For Loops

# Output List - Single Input to for loop
output "web_linuxvm_private_ip_address_list" {
  description = "Web Linux Virtual Machine Private IP"
  #value = azurerm_linux_virtual_machine.web_linuxvm.private_ip_address
  value = [for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.private_ip_address]
}

# Output Map  - Single Input to for loop
output "web_linuxvm_private_ip_address_map" {
  description = "Web Linux Virtual Machine Private IP"
  #value = azurerm_linux_virtual_machine.web_linuxvm.private_ip_address 
  value = {for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.name => vm.private_ip_address}
}

# Terraform keys() function: keys takes a map and returns a list containing the keys from that map.
output "web_linuxvm_private_ip_address_keys_function" {
  description = "Web Linux Virtual Machine Private IP"
  value = keys({for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.name => vm.private_ip_address})
}
# Terraform values() function: values takes a map and returns a list containing the values of the elements in that map.
output "web_linuxvm_private_ip_address_values_function" {
  description = "Web Linux Virtual Machine Private IP"
  value = values({for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.name => vm.private_ip_address})
}

# Output List - Two Inputs to for loop (here vm is Iterator like "i")
output "web_linuxvm_network_interface_id_list" {
  description = "Web Linux VM Network Interface ID"
  #value = azurerm_network_interface.web_linuxvm_nic.id
  value = [for vm, nic in azurerm_network_interface.web_linuxvm_nic: nic.id ]
}

# Output Map  - Two Inputs to for loop (here vm is Iterator like "i")
output "web_linuxvm_network_interface_id_map" {
  description = "Web Linux VM Network Interface ID"
  #value = azurerm_network_interface.web_linuxvm_nic.id
  value = {for vm, nic in azurerm_network_interface.web_linuxvm_nic: vm => nic.id }
}




