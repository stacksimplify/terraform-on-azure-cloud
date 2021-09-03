---
title: Azure Internal Load Balancer using Terraform
description: Create Azure Internal Load Balancer using Terraform
---

## Step-00: Introduction
### Concepts
1. Azure Storage Account with Azure File Share to copy Apache Config Files to Web VMs from local desktop Terraform Working Directory
2. Azure NAT Gateway for Outbound Connectivity from App VMs when associated to Internal LB (App LB)
3. App Linux VMs placed in App Subnets
4. Internal Standard Load Balancer (App LB)
### Azure Resources
1. azurerm_storage_account
2. azurerm_storage_container
3. azurerm_storage_blob
4. Terraform Input Variables
5. Terraform locals block
6. azurerm_public_ip
7. azurerm_nat_gateway
8. azurerm_subnet_nat_gateway_association
9. azurerm_network_interface
10. azurerm_linux_virtual_machine
11. Terraform Output Values
12. azurerm_lb
13. azurerm_lb_backend_address_pool
14. azurerm_lb_probe
15. azurerm_lb_rule
16. azurerm_network_interface_backend_address_pool_association
17. terraform.tfvars

### Update to Files
1. c7-03-web-linux-vmss-resource.tf: Update locals block custom data

### New Files: Storage Account
- Total we have 3 uses with this in our usecases we are building
1. Copy app1.conf to Web VMSS Linux VMs where in that app1.conf file will be used by Web VMSS Linux VMs to proxy to App Internal LB
2. When we are building end to end SSL using Azure Application Gateways and Azure VMSS (Internet -> AGLB(SSL) -> VMSS (SSL)) this container helps to push SSL Certificates, Private Keys to VMSS Apache.
3. When we are using Azure Application Gateways, it needs Error Pages related Static Website on Azure Storage Container, so this will be used for that usecase too. 
- Using Terraform Provisioners we can only push files to VMs which we can access them from our local desktop via internet. 
1. c10-01-storage-account-input-variables.tf
2. c10-02-storage-account.tf
3. c10-03-storage-account-outputs.tf
4. app-scripts/app1.conf

### New Files: NAT Gateway
- As we are creating Internal SLB and Internal App VMs in `appsubnet` the default outbound for that respective subnet provided by Azure default will be overrided and our VM's will not be able to connect to Internet for installing `httpd` binaries using `custom_data`
- We need to deploy the `Azure NAT Gateway` for `appsubnet` to enable outbound connectivity for Virtual Machines in `appsubnet` when associated with Internal LB
1. c11-01-azure-nat-gateway-input-variables.tf
2. c11-02-azure-nat-gateway-resource.tf
3. c11-03-azure-nat-gateway-outputs.tf

### New Files: App Linux VMSS
- Create AppTier Linux VM Scale Set
1. c12-01-app-linux-vmss-input-variables.tf
2. c12-02-app-linux-vmss-nsg-inline-basic.tf
3. c12-03-app-linux-vmss-resource.tf
4. c12-04-app-linux-vmss-autoscaling-cpu-usage.tf
5. c12-05-app-linux-vmss-outputs.tf

### New Files: App Load Balancer (Internal Standard Load Balancer)
1. c13-01-app-loadbalancer-input-variables.tf
2. c13-02-app-loadbalancer-resource.tf
3. c13-03-app-loadbalancer-outputs.tf


## Step-01: c10-01-storage-account-Input-Variables.tf
```t
# Input variable definitions
variable "storage_account_name" {
  description = "The name of the storage account"
  type        = string
}
variable "storage_account_tier" {
  description = "Storage Account Tier"
  type        = string
}
variable "storage_account_replication_type" {
  description = "Storage Account Replication Type"
  type        = string
}
variable "storage_account_kind" {
  description = "Storage Account Kind"
  type        = string
}
variable "static_website_index_document" {
  description = "static website index document"
  type        = string
}
variable "static_website_error_404_document" {
  description = "static website error 404 document"
  type        = string
}
```
## Step-02: c10-02-storage-account.tf
```t
# Resource-1: Create Azure Storage account
resource "azurerm_storage_account" "storage_account" {
  name                = "${var.storage_account_name}${random_string.myrandom.id}"
  resource_group_name = azurerm_resource_group.rg.name

  location                 = var.resource_group_location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind             = var.storage_account_kind

  static_website {
    index_document     = var.static_website_index_document
    error_404_document = var.static_website_error_404_document
  }
}


# Resource-2: httpd files Container
resource "azurerm_storage_container" "httpd_files_container" {
  name                  = "httpd-files-container"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

# Locals Block with list of files to be uploaded
locals {
  httpd_conf_files = ["app1.conf"]
}
# Resource-3: httpd conf files upload to httpd-files-container
resource "azurerm_storage_blob" "httpd_files_container_blob_ssl" {
  for_each = toset(local.httpd_conf_files)
  name                   = each.value
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.httpd_files_container.name
  type                   = "Block"
  source = "${path.module}/app-scripts/${each.value}"
}
```

## Step-03: c10-03-storage-account-outputs.tf
```t
# Storage Account Outputs
output "storage_account_primary_access_key" {
  value = azurerm_storage_account.storage_account.primary_access_key
  sensitive = true
}
output "storage_account_primary_web_endpoint" {
  value = azurerm_storage_account.storage_account.primary_web_endpoint
}
output "storage_account_primary_web_host" {
  value = azurerm_storage_account.storage_account.primary_web_host
}
output "storage_account_name" {
   value = azurerm_storage_account.storage_account.name 
}
```

## Step-04: c11-01-azure-nat-gateway-input-variables.tf
```t
# Input Variables Place holder file
```

## Step-05: c11-02-azure-nat-gateway-resource.tf
```t

# Resource-1: Create Public IP for Azure NAT Gateway
resource "azurerm_public_ip" "natgw_publicip" {
  name                = "${local.resource_name_prefix}-natgw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Resource-2: Create Azure NAT Gateway
resource "azurerm_nat_gateway" "natgw" {
  name                = "${local.resource_name_prefix}-natgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

# Resource-3: Associate Azure NAT Gateway and Public IP
resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_associate" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.natgw_publicip.id
}

# Resource-4: Associate AppSubnet and Azure NAT Gateway
resource "azurerm_subnet_nat_gateway_association" "natgw_appsubnet_associate" {
  subnet_id      = azurerm_subnet.appsubnet.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}
```

## Step-06: c11-03-azure-nat-gateway-outputs.tf
```t
# NAT Gateway ID
output "nat_gw_id" {
  description = "Azure NAT Gateway ID"
  value = azurerm_nat_gateway.natgw.id 
}

# NAT Gateway Public IP
output "nat_gw_public_ip" {
  description = "Azure NAT Gateway Public IP Address"
  value = azurerm_public_ip.natgw_publicip.ip_address
}
```

## Step-07: c12-01-app-linux-vmss-input-variables.tf
```t
# Linux VM Input Variables Placeholder file.
```

## Step-08: c12-02-app-linux-vmss-nsg-inline-basic.tf
```t
# Create Network Security Group using Terraform Dynamic Blocks
resource "azurerm_network_security_group" "app_vmss_nsg" {
  name                = "${local.resource_name_prefix}-app-vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.app_vmss_nsg_inbound_ports
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

/*
# Create Network Security Group - Regular
resource "azurerm_network_security_group" "app_vmss_nsg" {
  name                = "${local.resource_name_prefix}-app-vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "inbound-rule-HTTP"
    description                = "Inbound Rule"    
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "inbound-rule-HTTPS"
    description                = "Inbound Rule"    
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "inbound-rule-SSH"
    description                = "Inbound Rule"    
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
*/

```

## Step-09:c12-03-app-linux-vmss-resource.tf
```t
# Locals Block for custom data
locals {
appvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd  
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo chmod -R 777 /var/www/html 
sudo mkdir /var/www/html/appvm
sudo echo "Welcome to stacksimplify - AppVM App1 - VM Hostname: $(hostname)" > /var/www/html/index.html
sudo echo "Welcome to stacksimplify - AppVM App1 - VM Hostname: $(hostname)" > /var/www/html/appvm/hostname.html
sudo echo "Welcome to stacksimplify - AppVM App1 - App Status Page" > /var/www/html/appvm/status.html
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(255, 99, 71);"> <h1>Welcome to Stack Simplify - AppVM APP-1 </h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/appvm/index.html
sudo curl -H "Metadata:true" --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/appvm/metadata.html
CUSTOM_DATA  
}


# Resource: Azure Linux Virtual Machine Scale Set - App1
resource "azurerm_linux_virtual_machine_scale_set" "app_vmss" {
  name                = "${local.resource_name_prefix}-app-vmss"
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
    name    = "app-vmss-nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.app_vmss_nsg.id
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.appsubnet.id  
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.app_lb_backend_address_pool.id]
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.appvm_custom_data)  
}
```

## Step-10: c12-04-app-linux-vmss-autoscaling-default-profile.tf
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
  4. LB SYN Count Metric Rules (JUST FOR firing Scale-Up and Scale-In Events for Testing and also knowing in addition to current VMSS Resource, we can also create Autoscaling rules for VMSS based on other Resource usage like Load Balancer)
    1. Scale-Up Rule: Increase VMs by 1 when LB SYN Count is greater than 10 Connections (Average)
    2. Scale-Up Rule: Decrease VMs by 1 when LB SYN Count is less than 10 Connections (Average)    
*/

resource "azurerm_monitor_autoscale_setting" "app_vmss_autoscale" {
  name                = "${local.resource_name_prefix}-app-vmss-autoscale-profiles"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app_vmss.id
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
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app_vmss.id
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

## Step-11: c12-05-app-linux-vmss-outputs.tf
```t
# VM Scale Set Outputs

output "app_vmss_id" {
  description = "App Virtual Machine Scale Set ID"
  value = azurerm_linux_virtual_machine_scale_set.app_vmss.id 
}
```

## Step-12: c13-01-app-loadbalancer-input-variables.tf
```t
# Input Variables place holder file
```

## Step-13: c13-02-app-loadbalancer-resource.tf
```t
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
```


## Step-14: c13-03-app-loadbalancer-outputs.tf
```t
# LB Private IP Address List
output "app_lb_private_ip_addresses" {
  description = "Load Balancer Public Address"
  value = [azurerm_lb.app_lb.private_ip_addresses]
}

# Load Balancer ID
output "app_lb_id" {
  description = "The Internal Load Balancer ID."
  value = azurerm_lb.app_lb.id 
}

# Load Balancer Frontend IP Configuration Block
output "app_lb_frontend_ip_configuration" {
  description = "LB frontend_ip_configuration Block"
  value = [azurerm_lb.app_lb.frontend_ip_configuration]
}
```

## Step-15: terraform.tfvars
```t
business_divsion = "hr"
environment = "dev"
resource_group_name = "rg"
resource_group_location = "eastus"
vnet_name = "vnet"
vnet_address_space = ["10.1.0.0/16"]

web_subnet_name = "websubnet"
web_subnet_address = ["10.1.1.0/24"]

app_subnet_name = "appsubnet"
app_subnet_address = ["10.1.11.0/24"]

db_subnet_name = "dbsubnet"
db_subnet_address = ["10.1.21.0/24"]

bastion_subnet_name = "bastionsubnet"
bastion_subnet_address = ["10.1.100.0/24"]

bastion_service_subnet_name = "AzureBastionSubnet"
bastion_service_address_prefixes = ["10.1.101.0/27"]

web_vmss_nsg_inbound_ports = [22, 80, 443]
app_vmss_nsg_inbound_ports = [22, 80, 443]

storage_account_name              = "staticwebsite"
storage_account_tier              = "Standard"
storage_account_replication_type  = "LRS"
storage_account_kind              = "StorageV2"
static_website_index_document     = "index.html"
static_website_error_404_document = "error.html"
```

## Step-16: app1.conf in app-scripts folder
```t
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
LoadModule proxy_http_module modules/mod_proxy_http.so

<VirtualHost *:80>
ServerName kubeoncloud.com
ProxyPreserveHost On
ProxyPass /webvm !

# Use when only IP Addresses are used - Section-15
ProxyPass / http://10.1.11.241/
ProxyPassReverse / http://10.1.11.241/

# Use the below when using Private DNS Section - Section-16
#ProxyPass / http://applb.terraformguru.com/
#ProxyPassReverse / http://applb.terraformguru.com/

DocumentRoot /var/www/html
<Directory /var/www/html>
Options -Indexes
Order allow,deny
Allow from all
</Directory>
</VirtualHost>
```

## Step-17: Execute Terraform Commands
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

## Step-18: Verify Resources Part-1
- **Important-Note:**  It will take 5 to 10 minutes to provision all the commands outlined in VM Custom Data
```t
# Verify Resources - Virtual Network
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnets (Web, App, DB, Bastion)
4. Azure Network Security Groups (Web, App, DB, Bastion)
5. View the topology
6. Verify Terraform Outputs in Terraform CLI

# Verify Resources - Web Linux VMSS 
1. Verify Web Linux VM Scale Sets
2. Verify Virtual Machines in VM Scale Sets
3. Verify Private IPs for Virtual Machines
4. Verify Autoscaling Policy

# Verify Resources - App Linux VMSS 
1. Verify App Linux VM Scale Sets
2. Verify Virtual Machines in VM Scale Sets
3. Verify Private IPs for Virtual Machines
4. Verify Autoscaling Policy


# Verify Resources - Bastion Host
1. Verify Bastion Host VM Public IP
2. Verify Bastion Host VM Network Interface
3. Verify Bastion VM
4. Verify Bastion VM -> Networking -> NSG Rules
5. Verify Bastion VM Topology

# Connect to Bastion Host VM
1. Connect to Bastion Host Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Host-LinuxVM-PublicIP>
sudo su - 
cd /tmp
ls 
2. terraform-azure.pem file should be present in /tmp directory


# 1. Connect to Web Linux VMs in Web VMSS using Bastion Host VM
1. Connect to Web Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PrivateIP-1>
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PrivateIP-2>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/webvm
ls -lrt
exit
exit

# 2. Connect to App Linux VMs in App VMSS using Bastion Host VM
1. Connect to App Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<App-LinuxVM-PrivateIP-1>
ssh -i ssh-keys/terraform-azure.pem azureuser@<App-LinuxVM-PrivateIP-2>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/appvm
ls -lrt
exit
exit

# Web LB: Verify Internet Facing: Standard Load Balancer Resources 
1. Verify Public IP Address for Standard Load Balancer
2. Verify Standard Load Balancer (SLB) Resource
3. Verify SLB - Frontend IP Configuration
4. Verify SLB - Backend Pools
5. Verify SLB - Health Probes
6. Verify SLB - Load Balancing Rules
7. Verify SLB - Insights
8. Verify SLB - Diagnose and Solve Problems

# App LB: Verify Internal Loadbalancer: Standard Load Balancer Resources 
1. Verify Standard Load Balancer (SLB) Resource - Internal LB
2. Verify ISLB - Frontend IP Configuration (IP should be appsubnet IP)
3. Verify ISLB - Backend Pools
4. Verify ISLB - Health Probes
5. Verify ISLB - Load Balancing Rules
6. Verify ISLB - Insights
7. Verify ISLB - Diagnose and Solve Problems
```
## Step-19: Verify Resources Part-2
- **Important-Note:** It will take 5 to 10 minutes to provision all the commands outlined in VM Custom Data
```t
# Verify Storage Account
1. Verify Storage Account
2. Verify Storage Container
3. Verify app1.conf in Storage Container
4. We are also enabling this container with error pages in that as a static website. That we will use during the Azure Application Gateway usecases. 

# Verify NAT Gateway
1. Verify NAT Gateway 
2. Verify NAT Gateway -> Outbound IP
3. Verify NAT Gateway -> Subnets Associated

# Verify App Linux VM
1. Verify Network Interface created for App Linux VM
2. Verify App Linux VM
3. Verify Network Security Groups associated with VM (App Subnet NSG)
4. View Topology at App Linux VM -> Networking
5. Verify if only private IP associated with App Linux VM
6. Connect to Bastion Host and from there connect to App linux VM

# Connect to Bastion Host
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Public-IP>
sudo su -
cd /tmp

# Connect to App Linux VM using Bastion Host and Verify Files
- Here App Linux VM will communicate to Internet via NAT Gateway (Outbound Communication) to download and install the "httpd" binary.
ssh -i terraform-azure.pem azureuser@<App-Linux-VM>
sudo su -
cd /var/log
tail -100f /var/log/cloud-init-output.log
cd /var/www/html
ls
cd appvm
ls

# Perform Curl Test on App VM
curl http://<APP-VM-private-IP>
curl http://10.1.11.4

# Sample Output
[root@hr-dev-app-linuxvm ~]# curl http://10.1.11.4
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-app-linuxvm ~]# 

# Exit from App VM
exit
exit

# Verify App LB
1. Verify Standard Load Balancer (SLB) Resource - App LB
3. Verify App SLB - Frontend IP Configuration
4. Verify App SLB - Backend Pools
5. Verify App SLB - Health Probes
6. Verify App SLB - Load Balancing Rules
7. Verify App SLB - Insights
8. Verify App SLB - Diagnose and Solve Problems

# From Bastion Host - perform Curl Test to Azure Internal Standard Load Balancer
curl http://<APP-Loadbalancer-IP>
curl http://10.1.11.241

## Sample Ouptut
[root@hr-dev-bastion-linuxvm tmp]# curl http://10.1.11.241
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-bastion-linuxvm tmp]# 


# Verify Web Linux VM
ssh -i terraform-azure.pem azureuser@<Web-Linux-VM>
sudo su -
cd /var/log
tail -100f /var/log/cloud-init-output.log # It took 600 seconds for full custom data provisioning
cd /var/www/html
ls
cd webvm
ls
cd /etc/httpd/conf.d
ls  # Verify app1.conf downloaded

# Sample Output at the end of 
  "snapshot": null
}
Cloud-init v. 19.4 running 'modules:final' at Thu, 05 Aug 2021 11:44:05 +0000. Up 32.90 seconds.
Cloud-init v. 19.4 finished at Thu, 05 Aug 2021 11:53:39 +0000. Datasource DataSourceAzure [seed=/dev/sr0].  Up 607.09 seconds
^C
[root@hr-dev-web-linuxvm log]# 

# From Web VM Host - perform Curl Test to Azure Internal Standard Load Balancer
curl http://<APP-Loadbalancer-IP>
curl http://10.1.11.241

# Sample Output
[root@hr-dev-web-linuxvm conf.d]# curl http://10.1.11.241
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-web-linuxvm conf.d]# 

# From Web VM Host - perform Curl Test using Web VM Private IP
curl http://<Web-VM-Private-IP>
curl http://10.1.1.4

# Sample Output
[root@hr-dev-web-linuxvm conf.d]# curl http://10.1.1.4
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-web-linuxvm conf.d]# 

# Access Application using Internet facing Azure Standard Load Balancer Public
## Web VM Files
http://<LB-Public-IP>/webvm/index.html # Should be served from web Linux VM
http://<LB-Public-IP>/webvm/metadata.html

## App VM Files
http://<LB-Public-IP>/ # index.html should be served from App Linux VM
http://<LB-Public-IP>/appvm/index.html # Should be served from app Linux VM
http://<LB-Public-IP>/appvm/metadata.html
```


## Step-20: Delete Resources
```t
# Delete Resources
terraform destroy 
[or]
terraform apply -destroy -auto-approve

# Important Notes
1. If any error occures during Destroy, again run same destroy command
2. If error continues during destroy consistently and no resources getting deleted, delete the Resource Group using Azure Portal Management Console.

# Error-1: Sample Error during Destroy
azurerm_subnet.appsubnet: Destruction complete after 21s
╷
│ Error: Error waiting for removal of Backend Address Pool Association for NIC "hr-dev-web-linuxvm-nic" (Resource Group "hr-dev-rg"): Code="OperationNotAllowed" Message="Operation 'startTenantUpdate' is not allowed on VM 'hr-dev-web-linuxvm' since the VM is marked for deletion. You can only retry the Delete operation (or wait for an ongoing one to complete)." Details=[]

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```

## Additional References - Reverse Proxy Outbound open on RedHat VM Apache2
```t
# Reference Link
https://confluence.atlassian.com/bitbucketserverkb/permission-denied-in-apache-logs-when-used-as-a-reverse-proxy-790957647.html
# Command
/usr/sbin/setsebool -P httpd_can_network_connect 1
```


## Additional Reference
- https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview

