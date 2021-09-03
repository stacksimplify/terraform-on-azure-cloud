---
title: Azure MySQL Single Server using Terraform
description: Create Azure MySQL Single Server using Terraform
---
## Step-00: Introduction
### Terraform Concepts
1. Input Variables `mysqldb.auto.tfvars`
2. Input Variables `secrets.tfvars` with `-var-file` argument

### Azure Concepts 
1. Create Azure MySQL Single Server and Sample Schema in it
2. Create `service endpoint policies` to allow traffic to specific azure resources from your virtual network over service endpoints
3. Create `Virtual Network Rule` to make a connection from Azure Virtual Network Subnet to Azure MySQL Single Server 
4. Create a `MySQL Firewall Rule` to allow Bastion Host to access MySQL DB. Understand MySQL Firewall rule concept. 

### Azure Resources
1. azurerm_mysql_server
2. azurerm_mysql_database
3. azurerm_mysql_firewall_rule
4. azurerm_mysql_virtual_network_rule


## Step-01:  Azure MySQL Single Server MySQL TF Configs
### Step-01-01: c11-01-mysql-servers-input-variables.tf
```t
# Input Variables
# DB Name
variable "mysql_db_name" {
  description = "Azure MySQL Database Name"
  type        = string
}

# DB Username - Enable Sensitive flag
variable "mysql_db_username" {
  description = "Azure MySQL Database Administrator Username"
  type        = string
}
# DB Password - Enable Sensitive flag
variable "mysql_db_password" {
  description = "Azure MySQL Database Administrator Password"
  type        = string
  sensitive   = true
}

# DB Schema Name
variable "mysql_db_schema" {
  description = "Azure MySQL Database Schema Name"
  type        = string
}
```
### Step-01-02: c11-02-mysql-servers-resource.tf
```t
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
```
### Step-01-03: c11-03-mysql-servers-output-values.tf
```t
# Output Values
output "mysql_server_fqdn" {
  description = "MySQL Server FQDN"
  value = azurerm_mysql_server.mysql_server.fqdn
}
```
### Step-01-04: mysqldb.auto.tfvars
```t
# MySQL DB Name
mysql_db_name = "mysql"
mysql_db_username = "dbadmin"
mysql_db_schema = "webappdb"
```
### Step-01-05: secrets.tfvars
```t
# Secret Variables (Should not be checked-in to Github)
mysql_db_password = "H@Sh1CoR3!"
```
## Step-02: Virtual Network Subnet Changes
## Step-02-01: c6-03-web-subnet-and-nsg.tf - Web Subnet
- Create service endpoint policies to allow traffic to specific azure resources from your virtual network over service endpoints. 
- Add `service_endpoints = [ "Microsoft.Sql" ]` for Web Subnet
```t
# Resource-1: Create WebTier Subnet
resource "azurerm_subnet" "websubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.web_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.web_subnet_address  
  service_endpoints = [ "Microsoft.Sql" ]
}

```
## Step-02-02: c6-03-web-subnet-and-nsg.tf - Locals Block
- Add Port 8080 for Web Subnet Inbound Port Rules in Locals Block 
```t
# Resource-4: Create NSG Rules
## Locals Block for Security Rules
locals {
  web_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "120" : "22", 
    "130" : "8080"
  } 
}
```

## Step-03: Application Configs
## Step-03-01: c7-01-web-linux-vmss-input-variables.tf
```t
# Linux VM Input Variables Placeholder file.
variable "web_vmss_nsg_inbound_ports" {
  description = "Web VMSS NSG Inbound Ports"
  type = list(string)
  default = [22, 80, 443, 8080]
}
```
## Step-03-02: terraform.tfvars
```t
# Add port 8080 for VMSS NSG Inbound Ports
web_vmss_nsg_inbound_ports = [22, 80, 443, 8080]
```
## Step-03-03: c7-03-web-linux-vmss-resource.tf - Locals Block Custom Data
```t
# Locals Block for custom data
locals {
webvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
#sudo yum update -y
# Stop Firewall and Disable it
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# Java App Install
sudo yum -y install java-11-openjdk
sudo yum -y install telnet
sudo yum -y install mysql
mkdir /home/azureuser/app3-usermgmt && cd /home/azureuser/app3-usermgmt
wget https://github.com/stacksimplify/temp1/releases/download/1.0.0/usermgmt-webapp.war -P /home/azureuser/app3-usermgmt 
export DB_HOSTNAME=${azurerm_mysql_server.mysql_server.fqdn}
export DB_PORT=3306
export DB_NAME=${azurerm_mysql_database.webappdb.name}
export DB_USERNAME="${azurerm_mysql_server.mysql_server.administrator_login}@${azurerm_mysql_server.mysql_server.fqdn}"
export DB_PASSWORD=${azurerm_mysql_server.mysql_server.administrator_login_password}
java -jar /home/azureuser/app3-usermgmt/usermgmt-webapp.war > /home/azureuser/app3-usermgmt/ums-start.log &
CUSTOM_DATA  
}
```
## Step-03-04: c7-03-web-linux-vmss-resource.tf - VMSS Resource
```t
# Resource: Azure Linux Virtual Machine Scale Set - App1
resource "azurerm_linux_virtual_machine_scale_set" "web_vmss" {
  # 1. Create VMSS only if Java App related DB Schema "webappdb" is created in MySQL Server
  # 2. Only create VMSS if DB is ready with Virtual Network Rule so connection for Java App can be established to DB
  depends_on = [azurerm_mysql_database.webappdb, azurerm_mysql_virtual_network_rule.mysql_virtual_network_rule] 
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
## Step-04: Application Gateway Configs - c9-02-application-gateway-resource.tf
- We will update the `backend_http_settings` block
  - cookie_based_affinity = "Enabled"
  - affinity_cookie_name = "ApplicationGatewayAffinity"
  - port = 8080
- We will update the `probe` block
  - port = 8080
  - path = "/login"
  - body = "Username"
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
```
## Step-05: Enable Bastion Host
## Step-05-01: c8-02-bastion-host-linuxvm.tf
- Enable all configs from file `c8-02-bastion-host-linuxvm.tf`
## Step-05-02: c8-03-move-ssh-key-to-bastion-host.tf
- Enable all configs from file  `c8-03-move-ssh-key-to-bastion-host.tf`
## Step-05-03: c8-05-bastion-outputs.tf
- Enable all configs from file `c8-05-bastion-outputs.tf`

## Step-06: TF Configs Untouched
1. c1-versions.tf
2. c2-generic-input-variables.tf
3. c3-locals.tf
4. c4-random-resources.tf
5. c5-resource-group.tf
6. c6-01-vnet-input-variables.tf
7. c6-02-virtual-network.tf
8. c6-04-app-subnet-and-nsg.tf
9. c6-05-db-subnet-and-nsg.tf
10. c6-06-bastion-subnet-and-nsg.tf
11. c6-07-ag-subnet-and-nsg.tf
12. c6-08-vnet-outputs.tf
13. c7-02-web-linux-vmss-nsg-inline-basic.tf
14. c7-04-web-linux-vmss-outputs.tf
15. c7-05-web-linux-vmss-autoscaling-default-profile.tf
16. c7-06-web-linux-vmss-autoscaling-default-and-recurrence-profiles.tf
17. c7-07-web-linux-vmss-autoscaling-default-recurrence-fixed-profiles.tf
18. c8-01-bastion-host-input-variables.tf
19. c8-04-AzureBastionService.tf
20. c9-01-application-gateway-input-variables.tf
21. c9-03-application-gateway-outputs.tf
22. c10-01-storage-account-input-variables.tf
23. c10-02-storage-account.tf
24. c10-03-storage-account-outputs.tf

## Step-07: Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan -var-file=secrets.tfvars

# Terraform Apply 
terraform apply -var-file=secrets.tfvars
```

## Step-08: Connect to MySQL DB from Bastion Host VM and VMSS VM
- Test from Bastion Host which confirms our Azure MySQL firewall rule test
- Test from VMSS VM1 or VM2 confirms that our `Azure MySQL Virtual Network rule` and `Web Subnet Service Endpoint Configs` we have enabled private communication from `Web Subnet hosted VM's to Azure MySQL Single Server`
```t
# SSH to Bastion Host
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Public-IP>
sudo su - 

# Connect to MySQL DB
mysql -h hr-dev-mysql.mysql.database.azure.com -u dbadmin@hr-dev-mysql -p 

# DB Password to use
mysql_db_password = "H@Sh1CoR3!"

# SSH to Web VMSS VM1 or VM2
ssh -i /tmp/terraform-azure.pem azureuser@<VMSS-VM1-Private-IP>
ssh -i /tmp/terraform-azure.pem azureuser@10.1.1.6

# Connect to MySQL DB from Web VMSS VM1 or VM2 (This happens via Virtual Network we created from Web Subnet to MySQL Server)
mysql -h hr-dev-mysql.mysql.database.azure.com -u dbadmin@hr-dev-mysql -p 
```
## Step-09: Verify VMSS VM1 or VM2 Custom Data installed Apps
- Verify `/var/log/cloud-init-output.log`
- Verify User Management Web Application (UMS App) startup log `/home/azureuser/app3-usermgmt/ums-start.log`

```t
# Verify VMSS VM1 or VM2  cloud-init-output.log
cd /var/log
tail -100f cloud-init-output.log

# Verify User Management UMS App in VMSS VM1 or VM2
cd /home/azureuser/app3-usermgmt
ls
tail -100f /home/azureuser/app3-usermgmt/ums-start.log
more /home/azureuser/app3-usermgmt/ums-start.log
```

## Step-10: Verify Application Gateway Health
- Go to Services -> Application Gateways -> hr-dev-web-ag -> Monitoring -> Backend Health
- Backend Health
- Health Probes -> Test Probe
- Insights

## Step-11: Verify by accessing Application
```t
# Update Host Entry
sudo vi /etc/hosts
<APP-GW-PublicIP> terraformguru.com 

# Custom Host Entries
20.85.193.158  terraformguru.com

# Access Application
http://terraformguru.com # Should redirect to https URL
https://terraformguru.com 
Username: admin101
Password: password101
- Test List User
- Test Create User
- Test login with newly created user

# Important Notes
1. User Management Web Application (UMS Web App) is coded in such a way during the startup of the application, it will create a default admin user in MySQL Database connected to it. 
2. If connection to MySQL Server fails when UMS Web App is starting, it will come online.  
```

## Step-12: Clean-up
```t
# Destroy Resources
terraform destroy -var-file=secrets.tfvars -auto-approve

# Delete Files
rm -rf .terraform*
rm -rf terraform.tfstate*
```

## Additional Reference
- [Use Virtual Network service endpoints and rules for Azure Database for MySQL](https://docs.microsoft.com/en-us/azure/mysql/concepts-data-access-and-security-vnet)