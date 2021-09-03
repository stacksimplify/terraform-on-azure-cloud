# Resource-1: Azure MySQL Server
resource "azurerm_mysql_server" "mysql_server" {
  name                = "${local.resource_name_prefix}-${var.mysql_db_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = var.mysql_db_username
  administrator_login_password = var.mysql_db_password

  #sku_name   = "B_Gen5_2" # Basic Tier - Azure Virtual Network Rules not supported
  sku_name   = "GP_Gen5_2" # General Purpose Tier - Supports Azure Virtual Network Rules
  storage_mb = 5120
  version    = "8.0"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = false
  ssl_minimal_tls_version_enforced  = "TLSEnforcementDisabled" 

}

# Resource-2: Azure MySQL Database / Schema
resource "azurerm_mysql_database" "webappdb" {
  name                = var.mysql_db_schema
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.mysql_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# Resource-3: Azure MySQL Firewall Rule - Allow access from Bastion Host Public IP
resource "azurerm_mysql_firewall_rule" "mysql_fw_rule" {
  name                = "allow-access-from-bastionhost-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.mysql_server.name
  start_ip_address    = azurerm_public_ip.bastion_host_publicip.ip_address
  end_ip_address      = azurerm_public_ip.bastion_host_publicip.ip_address
}

# Resource-4: Azure MySQL Virtual Network Rule
resource "azurerm_mysql_virtual_network_rule" "mysql_virtual_network_rule" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.mysql_server.name
  subnet_id           = azurerm_subnet.websubnet.id
}
