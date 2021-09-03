# DNS Zone Datasource Outputs
output "dns_zone_id" {
  value = data.azurerm_dns_zone.dns_zone.id
}
output "dns_zone_name" {
  value = data.azurerm_dns_zone.dns_zone.name
}

# FQDN 
output "fqdn_public_dns_1" {
  description = "FQDN Public DNS 1"
  value = azurerm_dns_a_record.dns_record.fqdn
}

output "fqdn_public_dns_2" {
  description = "FQDN Public DNS 2"
  value = azurerm_dns_a_record.dns_record_www.fqdn
}

output "fqdn_public_dns_3" {
  description = "FQDN Public DNS 3"
  value = azurerm_dns_a_record.dns_record_app1.fqdn
}