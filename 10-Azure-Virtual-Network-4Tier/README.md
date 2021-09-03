---
title: Azure Virtual Network Design using Terraform
description: Design 4-Tier Azure Virtual Network using Terraform
---

## Step-00: Introduction
### Azure Virtual Network Design
- We are going to design the 4-Tier Azure Virtual Network here
1. Azure Virtual Network
2. WebTier Subnet + WebTier Network Security Group (Ports 80, 443)
3. AppTier Subnet + AppTier Network Security Group (Ports 8080, 80, 443)
4. DBTier Subnet + DBTier Network Security Group  (Ports 3306, 1433, 5432)
5. Bastion Subnet + Bastion Network Security Group (Ports 80, 3389)
6. Terraform `for_each` Meta-Argument 
### Azure Resources created
1. azurerm_resource_group
2. azurerm_virtual_network
3. azurerm_subnet
4. azurerm_network_security_group
5. azurerm_subnet_network_security_group_association
6. azurerm_network_security_rule

### Terraform Concepts covered
1. Terraform Settings Block
2. Terraform Provider Block
3. Terraform Input Variables
4. Terraform Local Values Block
5. Terraform Random Resource `random_string`
6. Terraform `for_each` Meta-Argument
7. Terraform `depends_on` Meta-Argument
8. Terraform Output Values

## Step-01: c1-versions.tf
```t
# Terraform Block
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.0" 
    }
    random = {
      source = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Provider Block
provider "azurerm" {
 features {}          
}
```

## Step-02: c2-generic-input-variables.tf
```t
# Generic Input Variables
# Business Division
variable "business_divsion" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type = string
  default = "sap"
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type = string
  default = "dev"
}

# Azure Resource Group Name 
variable "resource_group_name" {
  description = "Resource Group Name"
  type = string
  default = "rg-default"  
}

# Azure Resources Location
variable "resource_group_location" {
  description = "Region in which Azure Resources to be created"
  type = string
  default = "eastus2"  
}
```

## Step-03: c3-locals.tf
```t
# Define Local Values in Terraform
locals {
  owners = var.business_divsion
  environment = var.environment
  resource_name_prefix = "${var.business_divsion}-${var.environment}"
  #name = "${local.owners}-${local.environment}"
  common_tags = {
    owners = local.owners
    environment = local.environment
  }
} 
```

## Step-04: c4-random-resources.tf
```t
# Random String Resource
resource "random_string" "myrandom" {
  length = 6
  upper = false 
  special = false
  number = false   
}
```

## Step-05: c5-resource-group.tf
```t
# Resource-1: Azure Resource Group
resource "azurerm_resource_group" "rg" {
  # name = "${local.resource_name_prefix}-${var.resource_group_name}"
  name = "${local.resource_name_prefix}-${var.resource_group_name}-${random_string.myrandom.id}"
  location = var.resource_group_location
  tags = local.common_tags
}
```

## Step-06: Design Azure Virtual Network
1. Azure Virtual Network
2. Web, App, DB, Bastion Subnets
3. Network Security Group for all these Subnets
4. Terraform Output Values for Azure Virtual Network

## Step-06-01: c6-01-vnet-input-variables.tf
```t
# Virtual Network, Subnets and Subnet NSG's

## Virtual Network
variable "vnet_name" {
  description = "Virtual Network name"
  type = string
  default = "vnet-default"
}
variable "vnet_address_space" {
  description = "Virtual Network address_space"
  type = list(string)
  default = ["10.0.0.0/16"]
}


# Web Subnet Name
variable "web_subnet_name" {
  description = "Virtual Network Web Subnet Name"
  type = string
  default = "websubnet"
}
# Web Subnet Address Space
variable "web_subnet_address" {
  description = "Virtual Network Web Subnet Address Spaces"
  type = list(string)
  default = ["10.0.1.0/24"]
}


# App Subnet Name
variable "app_subnet_name" {
  description = "Virtual Network App Subnet Name"
  type = string
  default = "appsubnet"
}
# App Subnet Address Space
variable "app_subnet_address" {
  description = "Virtual Network App Subnet Address Spaces"
  type = list(string)
  default = ["10.0.11.0/24"]
}


# Database Subnet Name
variable "db_subnet_name" {
  description = "Virtual Network Database Subnet Name"
  type = string
  default = "dbsubnet"
}
# Database Subnet Address Space
variable "db_subnet_address" {
  description = "Virtual Network Database Subnet Address Spaces"
  type = list(string)
  default = ["10.0.21.0/24"]
}


# Bastion / Management Subnet Name
variable "bastion_subnet_name" {
  description = "Virtual Network Bastion Subnet Name"
  type = string
  default = "bastionsubnet"
}
# Bastion / Management Subnet Address Space
variable "bastion_subnet_address" {
  description = "Virtual Network Bastion Subnet Address Spaces"
  type = list(string)
  default = ["10.0.100.0/24"]
}
```
## Step-06-02: c6-02-virtual-network.tf
```t
# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_name_prefix}-${var.vnet_name}"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = local.common_tags
}
```

## Step-06-03: c6-03-web-subnet-and-nsg.tf
```t
# Resource-1: Create WebTier Subnet
resource "azurerm_subnet" "websubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.web_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.web_subnet_address  
}

# Resource-2: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "web_subnet_nsg" {
  name                = "${azurerm_subnet.websubnet.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-3: Associate NSG and Subnet
resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.web_nsg_rule_inbound] # Every NSG Rule Association will disassociate NSG from Subnet and Associate it, so we associate it only after NSG is completely created - Azure Provider Bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/354    
  subnet_id                 = azurerm_subnet.websubnet.id
  network_security_group_id = azurerm_network_security_group.web_subnet_nsg.id
}

# Resource-4: Create NSG Rules
## Locals Block for Security Rules
locals {
  web_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "120" : "22"
  } 
}
## NSG Inbound Rule for WebTier Subnets
resource "azurerm_network_security_rule" "web_nsg_rule_inbound" {
  for_each = local.web_inbound_ports_map
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
  network_security_group_name = azurerm_network_security_group.web_subnet_nsg.name
}
```

## Step-06-04: c6-04-app-subnet-and-nsg.tf
```t
# Resource-1: Create AppTier Subnet
resource "azurerm_subnet" "appsubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.app_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.app_subnet_address  
}

# Resource-2: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "app_subnet_nsg" {
  name                = "${azurerm_subnet.appsubnet.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-3: Associate NSG and Subnet
resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.app_nsg_rule_inbound]    
  subnet_id                 = azurerm_subnet.appsubnet.id
  network_security_group_id = azurerm_network_security_group.app_subnet_nsg.id
}

# Resource-4: Create NSG Rules
## Locals Block for Security Rules
locals {
  app_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "120" : "8080",
    "130" : "22"
  } 
}
## NSG Inbound Rule for AppTier Subnets
resource "azurerm_network_security_rule" "app_nsg_rule_inbound" {
  for_each = local.app_inbound_ports_map
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
  network_security_group_name = azurerm_network_security_group.app_subnet_nsg.name
}
```

## Step-06-05: c6-05-db-subnet-and-nsg.tf
```t
# Resource-1: Create DBTier Subnet
resource "azurerm_subnet" "dbsubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.db_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.db_subnet_address  
}

# Resource-2: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "db_subnet_nsg" {
  name                = "${azurerm_subnet.dbsubnet.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-3: Associate NSG and Subnet
resource "azurerm_subnet_network_security_group_association" "db_subnet_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.db_nsg_rule_inbound]    
  subnet_id                 = azurerm_subnet.dbsubnet.id
  network_security_group_id = azurerm_network_security_group.db_subnet_nsg.id
}

# Resource-4: Create NSG Rules
## Locals Block for Security Rules
locals {
  db_inbound_ports_map = {
    "100" : "3306", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "1433",
    "120" : "5432"
  } 
}
## NSG Inbound Rule for DBTier Subnets
resource "azurerm_network_security_rule" "db_nsg_rule_inbound" {
  for_each = local.db_inbound_ports_map
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
  network_security_group_name = azurerm_network_security_group.db_subnet_nsg.name
}
```

## Step-06-06: c6-06-bastion-subnet-and-nsg.tf
```t
# Resource-1: Create Bastion / Management Subnet
resource "azurerm_subnet" "bastionsubnet" {
  name                 = "${azurerm_virtual_network.vnet.name}-${var.bastion_subnet_name}"  
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.bastion_subnet_address
}

# Resource-2: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "bastion_subnet_nsg" {
  name                = "${azurerm_subnet.bastionsubnet.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-3: Associate NSG and Subnet
resource "azurerm_subnet_network_security_group_association" "bastion_subnet_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.bastion_nsg_rule_inbound]      
  subnet_id                 = azurerm_subnet.bastionsubnet.id
  network_security_group_id = azurerm_network_security_group.bastion_subnet_nsg.id
}

# Resource-4: Create NSG Rules
## Locals Block for Security Rules
locals {
  bastion_inbound_ports_map = {
    "100" : "22", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "3389"
  } 
}
## NSG Inbound Rule for Bastion / Management Subnets
resource "azurerm_network_security_rule" "bastion_nsg_rule_inbound" {
  for_each = local.bastion_inbound_ports_map
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
  network_security_group_name = azurerm_network_security_group.bastion_subnet_nsg.name
}
```

## Step-06-07: c6-07-vnet-outputs.tf
```t
# Virtual Network Outputs
## Virtual Network Name
output "virtual_network_name" {
  description = "Virtual Network Name"
  value = azurerm_virtual_network.vnet.name
}
## Virtual Network ID
output "virtual_network_id" {
  description = "Virtual Network ID"
  value = azurerm_virtual_network.vnet.id
}

# Subnet Outputs (We will write for one web subnet and rest all we will ignore for now)
## Subnet Name 
output "web_subnet_name" {
  description = "WebTier Subnet Name"
  value = azurerm_subnet.websubnet.name
}

## Subnet ID 
output "web_subnet_id" {
  description = "WebTier Subnet ID"
  value = azurerm_subnet.websubnet.id
}

# Network Security Outputs
## Web Subnet NSG Name 
output "web_subnet_nsg_name" {
  description = "WebTier Subnet NSG Name"
  value = azurerm_network_security_group.web_subnet_nsg.name
}

## Web Subnet NSG ID 
output "web_subnet_nsg_id" {
  description = "WebTier Subnet NSG ID"
  value = azurerm_network_security_group.web_subnet_nsg.id
}
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

## Step-09: Verify Resources
```t
# Verify Resources - Virtual Network
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnets (Web, App, DB, Bastion)
4. Azure Network Security Groups (Web, App, DB, Bastion)
5. View the topology
6. Verify Terraform Outputs in Terraform CLI
```

## Step-10: Delete Resources
```t
# Delete Resources
terraform destroy 
terraform apply -destroy

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```