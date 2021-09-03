# Resource-1: Create Azure Standard Load Balancer
resource "azurerm_lb" "app_lb" {
  name                = "${local.resource_name_prefix}-app-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  frontend_ip_configuration {
    name                 = "app-lb-privateip-1"
    subnet_id = azurerm_subnet.appsubnet.id
    private_ip_address_allocation = "Static"
    private_ip_address_version = "IPv4"
    private_ip_address = "10.1.11.241"
  }
}
 
# Resource-3: Create LB Backend Pool
resource "azurerm_lb_backend_address_pool" "app_lb_backend_address_pool" {
  name                = "app-backend"
  loadbalancer_id     = azurerm_lb.app_lb.id
}

# Resource-4: Create LB Probe
resource "azurerm_lb_probe" "app_lb_probe" {
  name                = "tcp-probe"
  protocol            = "Tcp"
  port                = 80
  loadbalancer_id     = azurerm_lb.app_lb.id
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-5: Create LB Rule
resource "azurerm_lb_rule" "app_lb_rule_app1" {
  name                           = "app-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.app_lb.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.app_lb_backend_address_pool.id 
  probe_id                       = azurerm_lb_probe.app_lb_probe.id
  loadbalancer_id                = azurerm_lb.app_lb.id
  resource_group_name            = azurerm_resource_group.rg.name
}

/*
# Resource-6: Associate Network Interface and Standard Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "app_nic_lb_associate" {
  network_interface_id    = azurerm_network_interface.app_linuxvm_nic.id
  ip_configuration_name   = azurerm_network_interface.app_linuxvm_nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.app_lb_backend_address_pool.id
}
*/