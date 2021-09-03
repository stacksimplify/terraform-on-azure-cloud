# Azure LB Inbound NAT Rule
resource "azurerm_lb_nat_rule" "web_lb_inbound_nat_rule_22" {
  depends_on = [azurerm_linux_virtual_machine.web_linuxvm  ] # To effectively handle azurerm provider related dependency bugs during the destroy resources time
  count = var.web_linuxvm_instance_count
  name = "vm-${count.index}-ssh-${var.lb_inbound_nat_ports[count.index]}-vm-22"
  protocol = "Tcp"
  frontend_port = element(var.lb_inbound_nat_ports, count.index)
  backend_port = 22
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.web_lb.id
}

# Associate LB NAT Rule and VM Network Interface
resource "azurerm_network_interface_nat_rule_association" "web_nic_nat_rule_associate" {
  count = var.web_linuxvm_instance_count
  network_interface_id  = element(azurerm_network_interface.web_linuxvm_nic[*].id, count.index) 
  ip_configuration_name = element(azurerm_network_interface.web_linuxvm_nic[*].ip_configuration[0].name, count.index) 
  nat_rule_id           = element(azurerm_lb_nat_rule.web_lb_inbound_nat_rule_22[*].id, count.index)
}
