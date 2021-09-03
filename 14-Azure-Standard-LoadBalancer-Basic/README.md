---
title: Azure Standard Load Balancer using Terraform
description: Create Azure Standard Load Balancer using Terraform
---
## Step-00: Introduction
- We are going to create Azure Standard Load Balancer Resources as part of this demo.
1. azurerm_public_ip
2. azurerm_lb
3. azurerm_lb_backend_address_pool
4. azurerm_lb_probe
5. azurerm_lb_rule
6. azurerm_network_interface_backend_address_pool_association
7. Comment Azure Bastion Service as we already using Azure Bastion Host approach with Linux VM

## Step-01: c9-01-web-loadbalancer-input-variables.tf
```t
# Placeholder file for Load Balancer Input Variables
```

## Step-02: c9-02-web-loadbalancer-resource.tf
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


# Resource-6: Associate Network Interface and Standard Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb_associate" {
  network_interface_id    = azurerm_network_interface.web_linuxvm_nic.id
  ip_configuration_name   = azurerm_network_interface.web_linuxvm_nic.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id
}
```

## Step-03: c9-03-web-loadbalancer-outputs.tf
```t
# LB Public IP
output "web_lb_public_ip_address" {
  description = "Web Load Balancer Public Address"
  value = azurerm_public_ip.web_lbpublicip.ip_address
}

# Load Balancer ID
output "web_lb_id" {
  description = "Web Load Balancer ID."
  value = azurerm_lb.web_lb.id 
}

# Load Balancer Frontend IP Configuration Block
output "web_lb_frontend_ip_configuration" {
  description = "Web LB frontend_ip_configuration Block"
  value = [azurerm_lb.web_lb.frontend_ip_configuration]
}
```

## Step-04: c8-04-AzureBastionService.tf
- Comment Azure Bastion Service which takes longer time to create Resource
- Also we have the Azure Bastion Host Linux VM for us if required to login to Private VMs
```t
/*
# Azure Bastion Service - Resources
## Resource-1: Azure Bastion Subnet
resource "azurerm_subnet" "bastion_service_subnet" {
  name                 = var.bastion_service_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.bastion_service_address_prefixes
}

# Resource-2: Azure Bastion Public IP
resource "azurerm_public_ip" "bastion_service_publicip" {
  name                = "${local.resource_name_prefix}-bastion-service-publicip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Resource-3: Azure Bastion Service Host
resource "azurerm_bastion_host" "bastion_host" {
  name                = "${local.resource_name_prefix}-bastion-service"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_service_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_service_publicip.id
  }
}
*/
```

## Step-05: Execute Terraform Commands
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

## Step-06: Verify Resources
```t
# Verify Resources - Virtual Network
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnets (Web, App, DB, Bastion)
4. Azure Network Security Groups (Web, App, DB, Bastion)
5. View the topology
6. Verify Terraform Outputs in Terraform CLI

# Verify Resources - Web Linux VM 
1. Verify Network Interface created for Web Linux VM
2. Verify Web Linux VM
3. Verify Network Security Groups associated with VM (web Subnet NSG)
4. View Topology at Web Linux VM -> Networking
5. Verify if only private IP associated with Web Linux VM

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

# Connect to Web Linux VM using Bastion Host VM
1. Connect to Web Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PrivateIP>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/app1
ls -lrt
exit
exit

# Verify Standard Load Balancer Resources
1. Verify Public IP Address for Standard Load Balancer
2. Verify Standard Load Balancer (SLB) Resource
3. Verify SLB - Frontend IP Configuration
4. Verify SLB - Backend Pools
5. Verify SLB - Health Probes
6. Verify SLB - Load Balancing Rules
7. Verify SLB - Insights
8. Verify SLB - Diagnose and Solve Problems

# Access Application
http://<LB-Public-IP>
http://<LB-Public-IP>/app1/index.html
http://<LB-Public-IP>/app1/metadata.html
```

## Step-07: Delete Resources
```t
# Delete Resources
terraform destroy 
[or]
terraform apply -destroy -auto-approve

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```

## Step-08: Additional Cautionary Note
- When your Linux VM NIC is associated with Security Group, the deletion criteria has issues with Azure Provider
- Due to that below related errors might come. This is provider related bug. 
- In our usecase we didn't associate any NSG to VMs directly, we are using subnet level NSG, so this error will not come for us. 
- Even this error comes when we associate NSG with VM NIC, just go to Azure Portal Console and delete that resource group so that all associated resources will be deleted. 
```t
azurerm_public_ip.bastion_host_publicip: Still destroying... [id=/subscriptions/82808767-144c-4c66-a320-...Addresses/hr-dev-bastion-host-publicip, 10s elapsed]
azurerm_subnet.bastionsubnet: Still destroying... [id=/subscriptions/82808767-144c-4c66-a320-...vnet/subnets/hr-dev-vnet-bastionsubnet, 10s elapsed]
azurerm_subnet.bastionsubnet: Destruction complete after 10s
azurerm_public_ip.bastion_host_publicip: Destruction complete after 12s
╷
│ Error: Error waiting for removal of Backend Address Pool Association for NIC "hr-dev-linuxvm-nic" (Resource Group "hr-dev-rg"): Code="OperationNotAllowed" Message="Operation 'startTenantUpdate' is not allowed on VM 'hr-dev-linuxvm1' since the VM is marked for deletion. You can only retry the Delete operation (or wait for an ongoing one to complete)." Details=[]
│
```