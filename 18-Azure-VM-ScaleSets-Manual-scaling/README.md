---
title: Azure Virtual Machine Scale Sets with Terraform
description: Create Azure Virtual Machine Scale Sets with Terraform
---

## Step-00: Introduction
- Create Azure Virtual Machine Scale Sets
- Associate Azure Virtual Machine Scale Sets with Azure Standard Load Balancer
- Terraform Dynamic Blocks
- Network Security Group with Inline Security Rules (Nested Blocks)
- Inline Network Security Rules - Re-Implement with Dynamic Blocks


### New Files: Web Linux VMSS
1. c7-01-web-linux-vmss-input-variables.tf
2. c7-02-web-linux-vmss-nsg-inline-basic.tf
3. c7-03-web-linux-vmss-resource.tf
4. c7-04-web-linux-vmss-autoscaling-cpu-usage.tf
5. c7-05-web-linux-vmss-outputs.tf

### Update Files
6. c9-02-web-loadbalancer-resource.tf: Comment Resource-6
7. terraform.tfvars: Add VMSS NSG variable

## Step-01: c7-01-web-linux-vmss-input-variables.tf
```t
# Linux VM Input Variables Placeholder file.
variable "web_vmss_nsg_inbound_ports" {
  description = "Web VMSS NSG Inbound Ports"
  type = list(string)
  default = [22, 80, 443]
}
```
## Step-02: c7-02-web-linux-vmss-nsg-inline-basic.tf
```t
# Create Network Security Group using Terraform Dynamic Blocks
resource "azurerm_network_security_group" "web_vmss_nsg" {
  name                = "${local.resource_name_prefix}-web-vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic "security_rule" {
    for_each = var.web_vmss_nsg_inbound_ports
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
resource "azurerm_network_security_group" "web_vmss_nsg" {
  name                = "${local.resource_name_prefix}-web-vmss-nsg"
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

## Step-03: c7-03-web-linux-vmss-resource.tf
```t
# Locals Block for custom data
locals {
webvm_custom_data = <<CUSTOM_DATA
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
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.webvm_custom_data)  
}
```

## Step-04: c7-04-web-linux-vmss-autoscaling-cpu-usage.tf
```t
#-----------------------------------------------
# Auto Scaling for Virtual machine scale set
#-----------------------------------------------
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_autoscale_setting
# Placeholder till next section and next demo
```

## Step-05: c7-05-web-linux-vmss-outputs.tf
```t
# VM Scale Set Outputs
output "web_vmss_id" {
  description = "Web Virtual Machine Scale Set ID"
  value = azurerm_linux_virtual_machine_scale_set.web_vmss.id 
}
```

## Step-06: c9-02-web-loadbalancer-resource.tf
- Comment Resource-6:`azurerm_network_interface_backend_address_pool_association`
```t
# Resource-1: Create Public IP Address for Azure Load Balancer
resource "azurerm_public_ip" "web_lbpublicip" {
  name                = "${local.resource_name_prefix}-lbpublicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
  tags = local.common_tags
}

# Resource-2: Create Azure Standard Load Balancer
resource "azurerm_lb" "web_lb" {
  name                = "${local.resource_name_prefix}-web-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  frontend_ip_configuration {
    name                 = "web-lb-publicip-1"
    public_ip_address_id = azurerm_public_ip.web_lbpublicip.id
  }
}
 
# Resource-3: Create LB Backend Pool
resource "azurerm_lb_backend_address_pool" "web_lb_backend_address_pool" {
  name                = "web-backend"
  loadbalancer_id     = azurerm_lb.web_lb.id
}

# Resource-4: Create LB Probe
resource "azurerm_lb_probe" "web_lb_probe" {
  name                = "tcp-probe"
  protocol            = "Tcp"
  port                = 80
  loadbalancer_id     = azurerm_lb.web_lb.id
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-5: Create LB Rule
resource "azurerm_lb_rule" "web_lb_rule_app1" {
  name                           = "web-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id 
  probe_id                       = azurerm_lb_probe.web_lb_probe.id
  loadbalancer_id                = azurerm_lb.web_lb.id
  resource_group_name            = azurerm_resource_group.rg.name
}

/*
# Resource-6: Associate Network Interface and Standard Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb_associate" {
  network_interface_id    = azurerm_network_interface.web_linuxvm_nic.id
  ip_configuration_name   = azurerm_network_interface.web_linuxvm_nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id
}
*/
```

## Step-07: terraform.tfvars
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
```

## Step-08: Execute Terraform Commands
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

## Step-09: Verify Resources Part-1
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


# Web LB: Verify Internet Facing: Standard Load Balancer Resources 
1. Verify Public IP Address for Standard Load Balancer
2. Verify Standard Load Balancer (SLB) Resource
3. Verify SLB - Frontend IP Configuration
4. Verify SLB - Backend Pools
5. Verify SLB - Health Probes
6. Verify SLB - Load Balancing Rules
7. Verify SLB - Insights
8. Verify SLB - Diagnose and Solve Problems

# Perform Curl Test on App VM
curl http://<LB-Public-IP>
curl http://<LB-Public-IP>
```

## Step-10: Delete Resources
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
