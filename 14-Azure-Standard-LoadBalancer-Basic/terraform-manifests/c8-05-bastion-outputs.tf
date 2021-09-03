## Bastion Host Public IP Output
output "bastion_host_linuxvm_public_ip_address" {
  description = "Bastion Host Linux VM Public Address"
  value = azurerm_public_ip.bastion_host_publicip.ip_address
}

