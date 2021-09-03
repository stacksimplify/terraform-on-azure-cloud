# Output Values
output "mysql_server_fqdn" {
  description = "MySQL Server FQDN"
  value = azurerm_mysql_server.mysql_server.fqdn
}