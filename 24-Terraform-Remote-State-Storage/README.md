---
title: Terraform Remote State Storage & Locking
description: Learn about Terraform Remote State Storage & Locking
---
## Step-01: Introduction
- Understand Terraform Backends
- Understand about Remote State Storage and its advantages
- This state is stored by default in a local file named `terraform.tfstate`, but it can also be stored remotely, which works better in a team environment.
- Create Azure Storage Account to store `terraform.tfstate` file and enable backend configurations in terraform settings block
- All the TF Configs copy from Section-19

## Step-02: Create Azure Storage Account
### Step-02-01: Create Resource Group
- Go to Resource Groups -> Add 
- **Resource Group:** terraform-storage-rg 
- **Region:** East US
- Click on **Review + Create**
- Click on **Create**

### Step-02-02: Create Azure Storage Account
- Go to Storage Accounts -> Add
- **Resource Group:** terraform-storage-rg 
- **Storage Account Name:** terraformstate201 (THIS NAME SHOULD BE UNIQUE ACROSS AZURE CLOUD)
- **Region:** East US
- **Performance:** Standard
- **Redundancy:** Geo-Redundant Storage (GRS)
- In `Data Protection`, check the option `Enable versioning for blobs`
- REST ALL leave to defaults
- Click on **Review + Create**
- Click on **Create**

### Step-02-03: Create Container in Azure Storage Account
- Go to Storage Account -> `terraformstate201` -> Containers -> `+Container`
- **Name:** tfstatefiles
- **Public Access Level:** Private (no anonymous access)
- Click on **Create**


## Step-03: c1-versions.tf
- **Reference Sub-folder:** terraform-manifests
- [Terraform Backend as Azure Storage Account](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- Add the below listed Terraform backend block in `Terrafrom Settings` block in `c1-versions.tf`
```t
# Terraform State Storage to Azure Storage Container
  backend "azurerm" {
    resource_group_name   = "terraform-storage-rg"
    storage_account_name  = "terraformstate201"
    container_name        = "tfstatefiles"
    key                   = "project-1-eastus2-terraform.tfstate"
  }   
```
- project-1-eastus2-vmss

## Step-04: c3-locals.tf
- Update `resource_name_prefix` altered to have region name in resources.  
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

## Step-05: Comment Bastion Host TF Configs (Optional)
1. c8-01-bastion-host-input-variables.tf
2. c8-02-bastion-host-linuxvm.tf
3. c8-03-move-ssh-key-to-bastion-host.tf
4. c8-04-AzureBastionService.tf - Already commented
5. c8-05-bastion-outputs.tf
6. terraform.tfvars
```t
#bastion_service_subnet_name = "AzureBastionSubnet"
#bastion_service_address_prefixes = ["10.1.101.0/27"]
```

## Step-06: Add Domain Label for Web Load Balancer Public IP
- Required for Next demo when we implement Azure Traffic Manager 
```t
# Resource-1: Create Public IP Address for Azure Load Balancer
resource "azurerm_public_ip" "web_lbpublicip" {
  name                = "${local.resource_name_prefix}-lbpublicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
  tags = local.common_tags
  # "domain_name_label" required for Azure Traffic Manager
  domain_name_label = azurerm_resource_group.rg.name  
}
```

## Step-07: terraform.tfvars
- Change `resource_group_location` to `eastus2`
```t
resource_group_location = "eastus2"
```

## Step-08: c9-03-web-loadbalancer-outputs.tf
- Add LB Public ID related output in Web Load Balancer.
- This we are going to use in `project-3-azure-traffic-manager` using `Terraform Remote State Datasource` in next demo.
```t
# LB Public IP ID
output "web_lb_public_ip_address_id" {
  description = "Web Load Balancer Public Address Resource ID"
  value = azurerm_public_ip.web_lbpublicip.id
}
```


## Step-09: Test with Remote State Storage Backend
```t
# Terraform Initialize
terraform init
## Sample CLI Output
Initializing the backend...
Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.

# Validate Terraform configuration files
terraform validate

# Review the terraform plan
terraform plan 
Observation:
1. Acquiring state lock. This may take a few moments...

# Create Resources 
terraform apply -auto-approve

# Verify Azure Storage Account for project-1-eastus2-terraform.tfstate file
Observation: 
1. Finally at this point you should see the project-1-eastus2-terraform.tfstate file in Azure Storage Account with content in it.

# Access Application
http://<LB-Public-IP>
```

## Step-10: Storage Account Container Versioning Test
- Update in `c3-locals.tf` 
- Uncomment Demo tag
```t
  common_tags = {
    Service = local.service_name
    Owner   = local.owner
    Tag = "demo-tag1"  # Uncomment during step-08
  }
```
- Execute Terraform Commands
```t
# Review the terraform plan
terraform plan 

# Create Resources 
terraform apply -auto-approve

# Verify terraform.tfstate file in Azure Storage Account
Observation: 
1. New version of terraform.tfstate file will be created
2. Understand about Terraform State Locking 
3. terraform.tfsate file should be in "leased" state which means no one can apply changes using terraform to Azure Resources.
4. Once the changes are completed "terraform apply", Lease State should be in "Available" state. 
```


## Step-11: Destroy Resources
- Destroy Resources and Verify Storage Account `project-1-eastus2-terraform.tfstate` file Versioning
```t
# Destroy Resources
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*

# c3-locals.tf - Comment demo tag for students seamless demo
  common_tags = {
    Service = local.service_name
    Owner   = local.owner
    #Tag = "demo-tag1"  
  }
```


## References 
- [Terraform Backends](https://www.terraform.io/docs/language/settings/backends/index.html)
- [Terraform State Storage](https://www.terraform.io/docs/language/state/backends.html)
- [Terraform State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [Remote Backends - Enhanced](https://www.terraform.io/docs/language/settings/backends/remote.html)