# Resource-1: Azure Application Gateway Public IP
resource "azurerm_public_ip" "web_ag_publicip" {
  name                = "${local.resource_name_prefix}-web-ag-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"  
}

# Azure Application Gateway - Locals Block 
#since these variables are re-used - a locals block makes this more maintainable
locals {
  # Generic 
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
  redirect_configuration_name    = "${azurerm_virtual_network.vnet.name}-rdrcfg"


  # App1
  backend_address_pool_name_app1      = "${azurerm_virtual_network.vnet.name}-beap-app1"
  http_setting_name_app1              = "${azurerm_virtual_network.vnet.name}-be-htst-app1"
  probe_name_app1                = "${azurerm_virtual_network.vnet.name}-be-probe-app1"

  # HTTP Listener -  Port 80
  listener_name_http                  = "${azurerm_virtual_network.vnet.name}-lstn-http"
  request_routing_rule_name_http      = "${azurerm_virtual_network.vnet.name}-rqrt-http"
  frontend_port_name_http             = "${azurerm_virtual_network.vnet.name}-feport-http"


  # HTTPS Listener -  Port 443
  listener_name_https                  = "${azurerm_virtual_network.vnet.name}-lstn-https"
  request_routing_rule_name_https      = "${azurerm_virtual_network.vnet.name}-rqrt-https"
  frontend_port_name_https             = "${azurerm_virtual_network.vnet.name}-feport-https"
  ssl_certificate_name                 = "my-cert-1" 
}



# Resource-2: Azure Application Gateway - Standard
resource "azurerm_application_gateway" "web_ag" {
  depends_on = [ azurerm_storage_blob.static_container_blob  ]  
  name                = "${local.resource_name_prefix}-web-ag"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
# START: --------------------------------------- #
# SKU: Standard_v2 (New Version )
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    #capacity = 2
  }
  autoscale_configuration {
    min_capacity = 0
    max_capacity = 10
  }  
# END: --------------------------------------- #

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.agsubnet.id
  }

# Frontend Port  - HTTP Port 80
  frontend_port {
    name = local.frontend_port_name_http 
    port = 80    
  }

# Frontend Port  - HTTP Port 443
  frontend_port {
    name = local.frontend_port_name_https
    port = 443    
  }  

# Frontend IP Configuration
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.web_ag_publicip.id    
  }

  # App1 Configs
  backend_address_pool {
    name = local.backend_address_pool_name_app1
  }
  backend_http_settings {
    name                  = local.http_setting_name_app1
    #cookie_based_affinity = "Disabled"
    cookie_based_affinity = "Enabled"
    affinity_cookie_name = "ApplicationGatewayAffinity"
    #path                  = "/app1/"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = local.probe_name_app1
  }
  probe {
    name                = local.probe_name_app1
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    protocol            = "Http"
    port                = 8080
    path                = "/login"
    match { # Optional
      body              = "Username"
      status_code       = ["200"]
    }
  }   

# HTTP Listener - Port 80
  http_listener {
    name                           = local.listener_name_http
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_http
    protocol                       = "Http"    
  }
# HTTP Routing Rule - HTTP to HTTPS Redirect
  request_routing_rule {
    name                       = local.request_routing_rule_name_http
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_http 
    redirect_configuration_name = local.redirect_configuration_name
  }
# Redirect Config for HTTP to HTTPS Redirect  
  redirect_configuration {
    name = local.redirect_configuration_name
    redirect_type = "Permanent"
    target_listener_name = local.listener_name_https
    include_path = true
    include_query_string = true
  }  


# SSL Certificate Block
  ssl_certificate {
    name = local.ssl_certificate_name
    password = "kalyan"
    data = filebase64("${path.module}/ssl-self-signed/httpd.pfx")
  }

# HTTPS Listener - Port 443  
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"    
    ssl_certificate_name           = local.ssl_certificate_name    
    custom_error_configuration {
      custom_error_page_url = "${azurerm_storage_account.storage_account.primary_web_endpoint}502.html"
      status_code = "HttpStatus502"
    }
    custom_error_configuration {
      custom_error_page_url = "${azurerm_storage_account.storage_account.primary_web_endpoint}403.html"
      status_code = "HttpStatus403"
    }    
  }

# HTTPS Routing Rule - Port 443
  request_routing_rule {
    name                       = local.request_routing_rule_name_https
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_https
    backend_address_pool_name  = local.backend_address_pool_name_app1
    backend_http_settings_name = local.http_setting_name_app1    
  }


}
