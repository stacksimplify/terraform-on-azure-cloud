---
title: Azure Application Gateway Basics using Terraform
description: Create Azure Application Gateway Basics using Terraform
---
## Step-00: Introduction

## Step-01: c6-01-vnet-input-variables.tf
```t
# Application Gateway Subnet Name
variable "ag_subnet_name" {
  description = "Virtual Network Application Gateway Subnet Name"
  type = string
  default = "agsubnet"
}
# Application Gateway Subnet Address Space
variable "ag_subnet_address" {
  description = "Virtual Network Application Gateway Subnet Address Spaces"
  type = list(string)
  default = ["10.0.51.0/24"]
}
```

## Step-02: terraform.tfvars
```t
ag_subnet_name = "agsubnet"
ag_subnet_address = ["10.1.51.0/24"]
```

## Step-03: c6-07-ag-subnet-and-nsg.tf
```t
# Resource-1: Create Application Gateway Subnet
resource "azurerm_subnet" "agsubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.ag_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.ag_subnet_address  
}

# Resource-2: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "ag_subnet_nsg" {
  name                = "${azurerm_subnet.agsubnet.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-3: Associate NSG and Subnet
resource "azurerm_subnet_network_security_group_association" "ag_subnet_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.ag_nsg_rule_inbound] # Every NSG Rule Association will disassociate NSG from Subnet and Associate it, so we associate it only after NSG is completely created - Azure Provider Bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/354  
  subnet_id                 = azurerm_subnet.agsubnet.id
  network_security_group_id = azurerm_network_security_group.ag_subnet_nsg.id
}

# Resource-4: Create NSG Rules
## Locals Block for Security Rules
locals {
  ag_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "130" : "65200-65535"
  } 
}
## NSG Inbound Rule for Azure Application Gateway Subnets
resource "azurerm_network_security_rule" "ag_nsg_rule_inbound" {
  for_each = local.ag_inbound_ports_map
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
  network_security_group_name = azurerm_network_security_group.ag_subnet_nsg.name
}
```

## Step-04: Comment Bastion Host 
- Bastion host related code is end to end commented. 
- If you want you can enable the Bastion Host or Bastion Host Service.
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

## Step-05: c9-01-application-gateway-input-variables.tf
```t
# Input Variables Placeholder file.
```

## Step-06: c9-02-application-gateway-resource.tf - AG Public IP
```t
# Resource-1: Azure Application Gateway Public IP
resource "azurerm_public_ip" "web_ag_publicip" {
  name                = "${local.resource_name_prefix}-web-ag-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"  
}
```

## Step-07: c9-02-application-gateway-resource.tf - Locals Block
```t

# Azure Application Gateway - Locals Block 
#since these variables are re-used - a locals block makes this more maintainable
locals {
  # Generic 
  frontend_port_name             = "${azurerm_virtual_network.vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
  listener_name                  = "${azurerm_virtual_network.vnet.name}-httplstn"
  request_routing_rule1_name      = "${azurerm_virtual_network.vnet.name}-rqrt-1"

  # App1
  backend_address_pool_name_app1      = "${azurerm_virtual_network.vnet.name}-beap-app1"
  http_setting_name_app1              = "${azurerm_virtual_network.vnet.name}-be-htst-app1"
  probe_name_app1                = "${azurerm_virtual_network.vnet.name}-be-probe-app1"

}
```

## Step-08: c9-02-application-gateway-resource.tf - AG Resource
```t
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

  # Frontend Configs
  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.web_ag_publicip.id    
  }

  # Listener: HTTP 80
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  # App1 Configs
  backend_address_pool {
    name = local.backend_address_pool_name_app1
  }
  backend_http_settings {
    name                  = local.http_setting_name_app1
    cookie_based_affinity = "Disabled"
    #path                  = "/app1/"
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

  # Rule-1
  request_routing_rule {
    name                       = local.request_routing_rule1_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name_app1
    backend_http_settings_name = local.http_setting_name_app1
  }
}

```

## Step-09: c7-03-web-linux-vmss-resource.tf
- Associate Application Gateway to VMSS
```t
resource "azurerm_linux_virtual_machine_scale_set" "web_vmss" {
  name                = "${local.resource_name_prefix}-web-vmss"
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
    name    = "web-vmss-nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.web_vmss_nsg.id
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.websubnet.id  
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.web_ag.backend_address_pool[0].id]            
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.webvm_custom_data)  
}
```

## Step-10: c7-05-web-linux-vmss-autoscaling-default-profile.tf
- Comment / Remove LB SYN Count related to Metric Rules
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

resource "azurerm_monitor_autoscale_setting" "web_vmss_autoscale" {
  name                = "${local.resource_name_prefix}-web-vmss-autoscale-profiles"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
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

## Step-11: Execute Terraform Commands
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

## Step-12: Verify Resources
```t
# Azure Virtual Network Resources
1. Azure Virtual Network
2. Web, App, DB, Bastion and AG Subnets

# Azure Web VMSS
1. Azure VMSS
2. Azure VMSS Instances
3. Azure VMSS Autoscaling
4. Azure VMSS Topology

# Azure Application Gateway
1. AG Configuration Tab
2. AG Backend Pools
3. AG HTTP Settings
4. AG Frontend IP
5. AG SSL Settings (NONE)
6. AG Listeners
7. AG Rules
8. AG Health Probes
9. AG Insights

# Access Application
http://<AG-Public-IP>
http://<AG-Public-IP>/app1/index.html
http://<AG-Public-IP>/app1/metadata.html
http://<AG-Public-IP>/app1/status.html
http://<AG-Public-IP>/app1/hostname.html
```

## Step-13: Destroy Resources
```t
# Destroy Resources
terraform destroy -auto-approve
or
terraform apply -destroy -auto-approve

# Delete Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```