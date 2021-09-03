# Traffic Manager FQDN Output
output "traffic_manager_fqdn" {
  description = "Traffic Manager FQDN"
  value = azurerm_traffic_manager_profile.tm_profile.fqdn
}