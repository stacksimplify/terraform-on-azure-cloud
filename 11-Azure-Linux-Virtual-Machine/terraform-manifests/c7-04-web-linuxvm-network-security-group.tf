/*
# Resource-3 (Optional): Create Network Security Group and Associate to Linux VM Network Interface
# Resource-1: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "web_vmnic_nsg" {
  name                = "${azurerm_network_interface.web_linuxvm_nic.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-2: Associate NSG and Linux VM NIC
resource "azurerm_network_interface_security_group_association" "web_vmnic_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.web_vmnic_nsg_rule_inbound]
  network_interface_id      = azurerm_network_interface.web_linuxvm_nic.id
  network_security_group_id = azurerm_network_security_group.web_vmnic_nsg.id
}

# Resource-3: Create NSG Rules
## Locals Block for Security Rules
locals {
  web_vmnic_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "120" : "22"
  } 
}
## NSG Inbound Rule for WebTier Subnets
resource "azurerm_network_security_rule" "web_vmnic_nsg_rule_inbound" {
  for_each = local.web_vmnic_inbound_ports_map
  name                        = "Rule-Port-${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value 
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_vmnic_nsg.name
}
*/



