---
title: Azure Application Gateway Multisite Hosting
description: Create Azure Application Gateway Multisite Hosting using Terraform
---
## Step-00: Introduction
1. Update Locals Block to support Multiple Listeners and Routing Rules for Multisite Hosting
2. Create Two Listeners for App1 and App2
3. Create Two Routing Rules for App1 and App2

## Step-01: c9-02-application-gateway-resource.tf - Locals Block
```t
# Azure Application Gateway - Locals Block 
#since these variables are re-used - a locals block makes this more maintainable
locals { 
  # Generic 
  frontend_port_name             = "${azurerm_virtual_network.vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
  #url_path_map                   =  "${azurerm_virtual_network.vnet.name}-upm-app1-app2"  

  # App1
  backend_address_pool_name_app1      = "${azurerm_virtual_network.vnet.name}-beap-app1"
  http_setting_name_app1              = "${azurerm_virtual_network.vnet.name}-be-htst-app1"
  probe_name_app1                     = "${azurerm_virtual_network.vnet.name}-be-probe-app1"
  listener_name_app1                  = "${azurerm_virtual_network.vnet.name}-httplstn-app1"
  request_routing_rule_name_app1      = "${azurerm_virtual_network.vnet.name}-rqrt-app1"

  # App2
  backend_address_pool_name_app2      = "${azurerm_virtual_network.vnet.name}-beap-app2"
  http_setting_name_app2              = "${azurerm_virtual_network.vnet.name}-be-htst-app2"
  probe_name_app2                     = "${azurerm_virtual_network.vnet.name}-be-probe-app2"
  listener_name_app2                  = "${azurerm_virtual_network.vnet.name}-httplstn-app2"
  request_routing_rule_name_app2      = "${azurerm_virtual_network.vnet.name}-rqrt-app2"
}
```

## Step-02: c9-02-application-gateway-resource.tf - Listener Blocks
```t
# Listerner: HTTP Port 80 with app1.terraformguru.com 
  http_listener {
    name                           = local.listener_name_app1
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
    host_names = [ "app1.terraformguru.com"]    
  }

# Listerner: HTTP Port 80 with app2.terraformguru.com 
  http_listener {
    name                           = local.listener_name_app2
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
    host_names = [ "app2.terraformguru.com"]    
  }
```

## Step-03: c9-02-application-gateway-resource.tf - Routing Rule Blocks
```t

# Routing Rule - app1.terraformguru.com
  request_routing_rule {
    name                       = local.request_routing_rule_name_app1
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_app1
    backend_address_pool_name = local.backend_address_pool_name_app1
    backend_http_settings_name = local.http_setting_name_app1
  }

# Routing Rule - app2.terraformguru.com
  request_routing_rule {
    name                       = local.request_routing_rule_name_app2
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_app2
    backend_address_pool_name = local.backend_address_pool_name_app2
    backend_http_settings_name = local.http_setting_name_app2
  }  
```

## Step-04: Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-05: Verify Resources
```t
# Verify VNET Resources
1. Verify VNET
2. Verify Subnets
3. Verify NSG

# Verify VMSS Resources
1. Verify App1 VMSS
2. Verify App2 VMSS

# Azure Application Gateway
1. AG Configuration Tab
2. AG Backend Pools
3. AG HTTP Settings
4. AG Frontend IP
5. AG Listeners (App1 and App2 Listeners for Multisite Hosting)
6. AG Rules + Verify Routing Rules App1 and App2
7. AG Health Probes
8. AG Insights
```

## Step-06: Add Host Entries and Test
```t
# Add Host Entries
## Linux or MacOs
sudo vi /etc/hosts

### Host Entry Template
<AG-Public-IP>  app1.terraformguru.com
<AG-Public-IP>  app2.terraformguru.com

### Host Entry Template - Replace AG-Public-IP
20.81.19.52  app1.terraformguru.com
20.81.19.52  app2.terraformguru.com

# Access Application - app1.terraformguru.com
http://app1.terraformguru.com/index.html
http://app1.terraformguru.com/app1/index.html
http://app1.terraformguru.com/app1/metadata.html
http://app1.terraformguru.com/app1/status.html
http://app1.terraformguru.com/app1/hostname.html

# Access Application - app2.terraformguru.com
http://app2.terraformguru.com/index.html
http://app2.terraformguru.com/app2/index.html
http://app2.terraformguru.com/app2/metadata.html
http://app2.terraformguru.com/app2/status.html
http://app2.terraformguru.com/app2/hostname.html

# Remove / Comment Host Entries after testing 
## Linux or MacOs
sudo vi /etc/hosts
#20.81.19.52  app1.terraformguru.com
#20.81.19.52  app2.terraformguru.com
```

## Step-07: Destroy Resources
```t
# Destroy Resources
terraform destroy -auto-approve
or
terraform apply -destroy -auto-approve

# Delete Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```