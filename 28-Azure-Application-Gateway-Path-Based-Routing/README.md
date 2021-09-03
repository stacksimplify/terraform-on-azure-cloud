---
title: Azure Application Gateway Path based Routing
description: Create Azure Application Gateway Path based Routing using Terraform
---
## Step-00: Introduction
1. Context Path based Routing
  - /app1/* -> App1 VMSS
  - /app2/* -> App2 VMSS
2. Root Context Redirection to some external site
  - /*      -> External Site `stacksimplify.com`
  
## Step-01: c7-01-web-linux-vmss-input-variables.tf
```t
# Linux VM Input Variables Placeholder file.
variable "app1_web_vmss_nsg_inbound_ports" {
  description = "App1 Web VMSS NSG Inbound Ports"
  type = list(string)
  default = [22, 80, 443]
}

variable "app2_web_vmss_nsg_inbound_ports" {
  description = "App2 Web VMSS NSG Inbound Ports"
  type = list(string)
  default = [22, 80, 443]
}
```

## Step-02: App1 VMSS TF Configs
### Step-02-01: c7-02-web-linux-vmss-app1-nsg-inline-basic.tf
```t
# Create Network Security Group using Terraform Dynamic Blocks
resource "azurerm_network_security_group" "app1_web_vmss_nsg" {
  name                = "${local.resource_name_prefix}-app1-web-vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.app1_web_vmss_nsg_inbound_ports
    content {
      name                       = "inbound-rule-${security_rule.key}"
      description                = "Inbound Rule ${security_rule.key}"    
      priority                   = sum([100, security_rule.key])
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

```
### Step-02-02: c7-03-web-linux-vmss-app1-resource.tf
```t
# Locals Block for custom data
locals {
app1_webvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
#sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd  
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo chmod -R 777 /var/www/html 
sudo echo "Welcome to stacksimplify - WebVM App1 - VM Hostname: $(hostname)" > /var/www/html/index.html
sudo mkdir /var/www/html/app1
sudo echo "Welcome to stacksimplify - WebVM App1 - VM Hostname: $(hostname)" > /var/www/html/app1/hostname.html
sudo echo "Welcome to stacksimplify - WebVM App1 - App Status Page" > /var/www/html/app1/status.html
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(250, 210, 210);"> <h1>Welcome to Stack Simplify - WebVM APP-1 </h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/app1/index.html
sudo curl -H "Metadata:true" --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/app1/metadata.html
CUSTOM_DATA  
}


# Resource: Azure Linux Virtual Machine Scale Set - App1
resource "azurerm_linux_virtual_machine_scale_set" "app1_web_vmss" {
  name                = "${local.resource_name_prefix}-app1-web-vmss"
  #computer_name_prefix = "vmss-app1" # if name argument is not valid one for VMs, we can use this for VM Names
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh-keys/terraform-azure.pub")
  }

  source_image_reference {
    publisher = "RedHat"
    offer = "RHEL"
    sku = "83-gen2"
    version = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  upgrade_mode = "Automatic"
  
  network_interface {
    name    = "app1-web-vmss-nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.app1_web_vmss_nsg.id
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.websubnet.id  
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.web_ag.backend_address_pool[0].id]            
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.app1_webvm_custom_data)  
}
```
### Step-02-03: c7-04-web-linux-vmss-app1-autoscaling-default-profile.tf
```t
#-----------------------------------------------
# Auto Scaling for Virtual machine scale set
#-----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_autoscale_setting

/*
Resource: azurerm_monitor_autoscale_setting
- Notification Block
- Profile Block-1: Default Profile
  1. Capacity Block
  2. Percentage CPU Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when CPU usage is greater than 75%
    2. Scale-In Rule: Decrease VMs by 1when CPU usage is lower than 25%
  3. Available Memory Bytes Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when Available Memory Bytes is less than 1GB in bytes
    2. Scale-In Rule: Decrease VMs by 1 when Available Memory Bytes is greater than 2GB in bytes
  4. COMMENT - NOT APPLICABLE in APPLICATION GATEWAY CASE - LB SYN Count Metric Rules (JUST FOR firing Scale-Up and Scale-In Events for Testing and also knowing in addition to current VMSS Resource, we can also create Autoscaling rules for VMSS based on other Resource usage like Load Balancer)
    1. Scale-Up Rule: Increase VMs by 1 when LB SYN Count is greater than 10 Connections (Average)
    2. Scale-Up Rule: Decrease VMs by 1 when LB SYN Count is less than 10 Connections (Average)    
*/

resource "azurerm_monitor_autoscale_setting" "app1_web_vmss_autoscale" {
  name                = "${local.resource_name_prefix}-app1-web-vmss-autoscale-profiles"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id
  # Notification  
  notification {
      email {
        send_to_subscription_administrator    = true
        send_to_subscription_co_administrator = true
        custom_emails                         = ["myadminteam@ourorg.com"]
      }
    }    
################################################################################
################################################################################
#######################  Profile-1: Default Profile  ###########################
################################################################################
################################################################################    
# Profile-1: Default Profile 
  profile {
    name = "default"
  # Capacity Block     
    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    

###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  

  } # End of Profile-1


}
```
## Step-03: App2 VMSS TF Configs
### Step-03-01: c7-05-web-linux-vmss-app2-nsg-inline-basic.tf
```t
# Create Network Security Group using Terraform Dynamic Blocks
resource "azurerm_network_security_group" "app2_web_vmss_nsg" {
  name                = "${local.resource_name_prefix}-app2-web-vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.app2_web_vmss_nsg_inbound_ports
    content {
      name                       = "inbound-rule-${security_rule.key}"
      description                = "Inbound Rule ${security_rule.key}"    
      priority                   = sum([100, security_rule.key])
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}

```
### Step-03-02: c7-06-web-linux-vmss-app2-resource.tf
```t
# Locals Block for custom data
locals {
app2_webvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
#sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd  
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo chmod -R 777 /var/www/html 
sudo echo "Welcome to stacksimplify - WebVM App2 - VM Hostname: $(hostname)" > /var/www/html/index.html
sudo mkdir /var/www/html/app2
sudo echo "Welcome to stacksimplify - WebVM App2 - VM Hostname: $(hostname)" > /var/www/html/app2/hostname.html
sudo echo "Welcome to stacksimplify - WebVM App2 - App Status Page" > /var/www/html/app2/status.html
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(60, 179, 113);"> <h1>Welcome to Stack Simplify - WebVM APP-2 </h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/app2/index.html
sudo curl -H "Metadata:true" --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/app2/metadata.html
CUSTOM_DATA  
}


# Resource: Azure Linux Virtual Machine Scale Set - App2
resource "azurerm_linux_virtual_machine_scale_set" "app2_web_vmss" {
  name                = "${local.resource_name_prefix}-app2-web-vmss"
  #computer_name_prefix = "vmss-app1" # if name argument is not valid one for VMs, we can use this for VM Names
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh-keys/terraform-azure.pub")
  }

  source_image_reference {
    publisher = "RedHat"
    offer = "RHEL"
    sku = "83-gen2"
    version = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  upgrade_mode = "Automatic"
  
  network_interface {
    name    = "app2-web-vmss-nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.app2_web_vmss_nsg.id
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.websubnet.id  
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.web_ag.backend_address_pool[1].id]            
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.app2_webvm_custom_data)  
}
```
### Step-03-03: c7-07-web-linux-vmss-app2-autoscaling-default-profile.tf
```t
#-----------------------------------------------
# Auto Scaling for Virtual machine scale set
#-----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_autoscale_setting

/*
Resource: azurerm_monitor_autoscale_setting
- Notification Block
- Profile Block-1: Default Profile
  1. Capacity Block
  2. Percentage CPU Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when CPU usage is greater than 75%
    2. Scale-In Rule: Decrease VMs by 1when CPU usage is lower than 25%
  3. Available Memory Bytes Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when Available Memory Bytes is less than 1GB in bytes
    2. Scale-In Rule: Decrease VMs by 1 when Available Memory Bytes is greater than 2GB in bytes
  4. COMMENT - NOT APPLICABLE in APPLICATION GATEWAY CASE - LB SYN Count Metric Rules (JUST FOR firing Scale-Up and Scale-In Events for Testing and also knowing in addition to current VMSS Resource, we can also create Autoscaling rules for VMSS based on other Resource usage like Load Balancer)
    1. Scale-Up Rule: Increase VMs by 1 when LB SYN Count is greater than 10 Connections (Average)
    2. Scale-Up Rule: Decrease VMs by 1 when LB SYN Count is less than 10 Connections (Average)    
*/

resource "azurerm_monitor_autoscale_setting" "app2_web_vmss_autoscale" {
  name                = "${local.resource_name_prefix}-app2-web-vmss-autoscale-profiles"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id
  # Notification  
  notification {
      email {
        send_to_subscription_administrator    = true
        send_to_subscription_co_administrator = true
        custom_emails                         = ["myadminteam@ourorg.com"]
      }
    }    
################################################################################
################################################################################
#######################  Profile-1: Default Profile  ###########################
################################################################################
################################################################################    
# Profile-1: Default Profile 
  profile {
    name = "default"
  # Capacity Block     
    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    

###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Out 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  

  } # End of Profile-1


}
```

## Step-04: c7-08-web-linux-vmss-outputs.tf
```t
# VM Scale Set Outputs

output "app1_web_vmss_id" {
  description = "App1 Web Virtual Machine Scale Set ID"
  value = azurerm_linux_virtual_machine_scale_set.app1_web_vmss.id 
}

output "app2_web_vmss_id" {
  description = "App2 Web Virtual Machine Scale Set ID"
  value = azurerm_linux_virtual_machine_scale_set.app2_web_vmss.id 
}
```

## Step-05: Bastion Host and Service TF Configs Commented
1. c8-01-bastion-host-input-variables.tf
2. c8-02-bastion-host-linuxvm.tf
3. c8-03-move-ssh-key-to-bastion-host.tf
4. c8-04-AzureBastionService.tf
5. c8-05-bastion-outputs.tf
6. terraform.tfvars
```t
#bastion_service_subnet_name = "AzureBastionSubnet"
#bastion_service_address_prefixes = ["10.1.101.0/27"]
```

## Step-06: c9-01-application-gateway-input-variables.tf
```t
# Input Variables Placeholder file.
```

## Step-07: c9-02-application-gateway-resource.tf
```t
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
  frontend_port_name             = "${azurerm_virtual_network.vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
  listener_name                  = "${azurerm_virtual_network.vnet.name}-httplstn"
  request_routing_rule1_name     = "${azurerm_virtual_network.vnet.name}-rqrt-1"
  url_path_map                   =  "${azurerm_virtual_network.vnet.name}-upm-app1-app2"  

  # App1
  backend_address_pool_name_app1      = "${azurerm_virtual_network.vnet.name}-beap-app1"
  http_setting_name_app1              = "${azurerm_virtual_network.vnet.name}-be-htst-app1"
  probe_name_app1                = "${azurerm_virtual_network.vnet.name}-be-probe-app1"

  # App2
  backend_address_pool_name_app2      = "${azurerm_virtual_network.vnet.name}-beap-app2"
  http_setting_name_app2              = "${azurerm_virtual_network.vnet.name}-be-htst-app2"
  probe_name_app2                    = "${azurerm_virtual_network.vnet.name}-be-probe-app2"

  # Default Redirect on Root Context (/)
  redirect_configuration_name    = "${azurerm_virtual_network.vnet.name}-rdrcfg"

}



# Resource-2: Azure Application Gateway - Standard
resource "azurerm_application_gateway" "web_ag" {
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

# Front End Configs
  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.web_ag_publicip.id    
  }

# Listerner: HTTP Port 80
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

# App1 Backend Configs
  backend_address_pool {
    name = local.backend_address_pool_name_app1
  }
  backend_http_settings {
    name                  = local.http_setting_name_app1
    cookie_based_affinity = "Disabled"
    port                  = 80
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
    port                = 80
    path                = "/app1/status.html"
    match { # Optional
      body              = "App1"
      status_code       = ["200"]
    }
  }   


# App2 Backend Configs
  backend_address_pool {
    name = local.backend_address_pool_name_app2
  }
  backend_http_settings {
    name                  = local.http_setting_name_app2
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60  
    probe_name            = local.probe_name_app2    
  }  
  probe {
    name                = local.probe_name_app2
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    protocol            = "Http"
    port                = 80
    path                = "/app2/status.html"
    match { # Optional
      body              = "App2"
      status_code       = ["200"]
    }
  }  

# Path based Routing Rule
  request_routing_rule {
    name                       = local.request_routing_rule1_name
    rule_type                  = "PathBasedRouting"
    http_listener_name         = local.listener_name
    url_path_map_name           = local.url_path_map        
  }

# URL Path Map - Define Path based Routing    
  url_path_map {
    name = local.url_path_map  
    default_redirect_configuration_name = local.redirect_configuration_name
    path_rule {
      name = "app1-rule"
      paths = ["/app1/*"]
      backend_address_pool_name = local.backend_address_pool_name_app1
      backend_http_settings_name = local.http_setting_name_app1
    }
    path_rule {
      name = "app2-rule"
      paths = ["/app2/*"]
      backend_address_pool_name = local.backend_address_pool_name_app2
      backend_http_settings_name = local.http_setting_name_app2           
    }    
  }

  # Default Root Context (/ - Redirection Config)
  redirect_configuration {
    name = local.redirect_configuration_name
    redirect_type = "Permanent"
    target_url = "https://stacksimplify.com/azure-aks/azure-kubernetes-service-introduction/"
  }

}

```

## Step-08: c9-03-application-gateway-outputs.tf
```t
# Application Gateway Outputs
output "web_ag_id" {
  description = "Azure Application Gateway ID"  
  value = azurerm_application_gateway.web_ag.id 
}

output "web_ag_public_ip_1" {
  description = "Azure Application Gateway Public IP 1"  
  value = azurerm_public_ip.web_ag_publicip.ip_address
}
```

## Step-09: Execute Terraform Commands
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

## Step-10: Verify Resources
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
5. AG Listeners
6. AG Rules + Verify Routing Rules App1 and App2
7. AG Health Probes
8. AG Insights

# Access Application - App1 /app1/*
http://<AG-Public-IP>/app1/index.html
http://<AG-Public-IP>/app1/metadata.html
http://<AG-Public-IP>/app1/status.html
http://<AG-Public-IP>/app1/hostname.html

# Access Application - App2 /app2/*
http://<AG-Public-IP>/app2/index.html
http://<AG-Public-IP>/app2/metadata.html
http://<AG-Public-IP>/app2/status.html
http://<AG-Public-IP>/app2/hostname.html

# Access Application - Default Root Context /*
http://<AG-Public-IP>
```

## Step-11: Destroy Resources
```t
# Destroy Resources
terraform destroy -auto-approve
or
terraform apply -destroy -auto-approve

# Delete Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```