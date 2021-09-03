---
title: Azure Traffic Manager using Terraform
description: Create Azure Traffic Manager using Terraform
---
## Step-01: Introduction
- Understand about [Terraform Remote State Datasource](https://www.terraform.io/docs/language/state/remote-state-data.html)
- Terraform Remote State Storage Demo with two projects

## Step-02: Project-1: project-1-eastus2-vmss
- Review TF Configs in folder `project-1-eastus2-vmss`

## Step-03: Project-1: Execute Terraform Commands
```t
# Change Directory 
cd project-1-eastus2-vmss

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Observation
1. Verify all resources in eastus2 region
2. Verify Storage Account - TFState file
```
## Step-04: Project-2: project-2-westus2-vmss
- Review TF configs in folder `project-2-westus2-vmss`

## Step-05: Project-2: Execute Terraform Commands
```t
# Change Directory 
cd project-2-westus2-vmss

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Observation
1. Verify all resources in westus2 region
2. Verify Storage Account - TFState file
```

## Step-06: Project-3: project-3-azure-traffic-manager
- Folder: project-3-azure-traffic-manager

### Step-06-00: c0-terraform-remote-state-datasource.tf
- Understand in depth about Terraform Remote State Datasource
```t
# Project-1: East US2 Datasource
data "terraform_remote_state" "project1_eastus2" {
  backend = "azurerm"
  config = {
    resource_group_name   = "terraform-storage-rg"
    storage_account_name  = "terraformstate201"
    container_name        = "tfstatefiles"
    key                   = "project-1-eastus2-terraform.tfstate"
  }
}

# Project-2: West US2 Datasource
data "terraform_remote_state" "project2_westus2" {
  backend = "azurerm"
  config = {
    resource_group_name   = "terraform-storage-rg"
    storage_account_name  = "terraformstate201"
    container_name        = "tfstatefiles"
    key                   = "project-2-westus2-terraform.tfstate"
  }
}

/* 
1. Project-1: Web LB Public IP Address
data.terraform_remote_state.project1_eastus2.outputs.web_lb_public_ip_address_id
1. Project-2: Web LB Public IP Address
data.terraform_remote_state.project2_westus2.outputs.web_lb_public_ip_address_id
*/
```

### Step-06-01: c1-versions.tf
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
    null = {
      source = "hashicorp/null"
      version = ">= 3.0"
    }    
  }
# Terraform State Storage to Azure Storage Container
  backend "azurerm" {
    resource_group_name   = "terraform-storage-rg"
    storage_account_name  = "terraformstate201"
    container_name        = "tfstatefiles"
    key                   = "project-3-traffic-manager-terraform.tfstate"
  }   
}

# Provider Block
provider "azurerm" {
 features {}          
}
```
### Step-06-02: c2-generic-input-variables.tf
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
### Step-06-03: c3-locals.tf
```t
# Define Local Values in Terraform
locals {
  owners = var.business_divsion
  environment = var.environment
  #resource_name_prefix = "${var.business_divsion}-${var.environment}"
  resource_name_prefix = "${var.resource_group_location}-${var.business_divsion}-${var.environment}"
  common_tags = {
    owners = local.owners
    environment = local.environment
  }
} 
```
### Step-06-04: c4-random-resources.tf
```t
# Random String Resource
resource "random_string" "myrandom" {
  length = 6
  upper = false 
  special = false
  number = false   
}

```
### Step-06-05: c5-resource-group.tf
```t
# Resource-1: Azure Resource Group
resource "azurerm_resource_group" "rg" {
  # name = "${local.resource_name_prefix}-${var.resource_group_name}"
  name = "tm-${local.resource_name_prefix}-${var.resource_group_name}-${random_string.myrandom.id}"
  location = var.resource_group_location
  tags = local.common_tags
}

```
### Step-06-06: c6-traffic-manager.tf
```t
# Resource-1: Traffic Manager Profile
resource "azurerm_traffic_manager_profile" "tm_profile" {
  name                   = "mytfdemo-${random_string.myrandom.id}"
  resource_group_name    = azurerm_resource_group.rg.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "mytfdemo-${random_string.myrandom.id}"
    ttl           = 100
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
  
  tags = local.common_tags
}

# Traffic Manager Endpoint - Project-1-EastUs2
resource "azurerm_traffic_manager_endpoint" "tm_endpoint_project1_eastus2" {
  name                = "tm-endpoint-project1-eastus2"
  resource_group_name = azurerm_resource_group.rg.name
  profile_name        = azurerm_traffic_manager_profile.tm_profile.name
  type                = "azureEndpoints"
  target_resource_id  = data.terraform_remote_state.project1_eastus2.outputs.web_lb_public_ip_address_id
  weight              = 50
}


# Traffic Manager Endpoint - Project-2-WestUs2
resource "azurerm_traffic_manager_endpoint" "tm_endpoint_project2_westus2" {
  name                = "tm-endpoint-project2-westus2"
  resource_group_name = azurerm_resource_group.rg.name
  profile_name        = azurerm_traffic_manager_profile.tm_profile.name
  type                = "azureEndpoints"
  target_resource_id  = data.terraform_remote_state.project2_westus2.outputs.web_lb_public_ip_address_id 
  weight              = 50
}

```
### Step-06-07: c7-traffic-manager-outputs.tf
```t
# Traffic Manager FQDN Output
output "traffic_manager_fqdn" {
  description = "Traffic Manager FQDN"
  value = azurerm_traffic_manager_profile.tm_profile.fqdn
}
```
### Step-06-08: terraform.tfvars
```t
business_divsion = "hr"
environment = "dev"
resource_group_name = "rg"
resource_group_location = "eastus2"
```



## Step-07: Project-3: Execute Terraform Commands
```t
# Change Directory 
cd project-3-azure-traffic-manager

# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Observation
1. Verify Azure Traffic Manager Resources
2. Verify Storage Account - TFState file

# Access Apps from both regions eastus2 and westus2
http://<Traffic-Manager-DNS-Name>
```

## Step-08: Project-3: Clean-Up
```t
# Change Directory 
cd project-3-azure-traffic-manager

# Destroy Resources
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*
```

## Step-09: Project-2: Clean-Up
```t
# Change Directory 
cd project-2-westus2-vmss

# Destroy Resources
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*
```

## Step-10: Project-1: Clean-Up
```t
# Change Directory 
cd project-1-eastus2-vmss

# Destroy Resources
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*
```
