# NAT Gateway ID
output "nat_gw_id" {
  description = "Azure NAT Gateway ID"
  value = azurerm_nat_gateway.natgw.id 
}

# NAT Gateway Public IP
output "nat_gw_public_ip" {
  description = "Azure NAT Gateway Public IP Address"
  value = azurerm_public_ip.natgw_publicip.ip_address
}
