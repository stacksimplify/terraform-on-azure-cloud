---
title: Azure Application Gateway SSL with Key Vault
description: Create Azure Application Gateway SSL Self-Signed with Key Vault using Terraform
---
## Step-00: Introduction
### Important Order of steps to achieve this use-case
0. Leverage `Section-30-Azure-Application-Gateway-SSL-SelfSigned` and build on top of them all the below features
1. Create [User-assigned Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview#how-can-i-use-managed-identities-for-azure-resources)
2. Assign the Managed Identity to Application Gateway (identity block in ag)
3. Add a [User-assigned Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview#how-can-i-use-managed-identities-for-azure-resources) to your Key Vault access policy (Resource: azurerm_key_vault_access_policy)
4. Import the SSL certificate into Key Vault and store the certificate SID in a variable
5. Update 443 Listner in AG to access SSL cert from Key Vault
### Important Note
- This approach helps us for real SSL Certificates (Not self-signed) which are managed externally means generating CSR, submit to CA and get Certificate. Those can be imported to Key Vault and referenced in Azure Application Gateway using this approach. 
- Instead of the `httpd.pfx` currently which contains self-signed certificate, in real ssl certificate case `httpd.pfx` will have real ssl certificate and private key, rest all as-is. 


## Step-01: c9-04-application-gateway-managed-identity.tf
```t
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
resource "azurerm_user_assigned_identity" "appag_umid" {
  name = "${local.resource_name_prefix}-appgw-umid"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Output Values
output "user_assigned_identity_id" {
  value = azurerm_user_assigned_identity.appag_umid.id
}
output "user_assigned_identity_principal_id" {
  value = azurerm_user_assigned_identity.appag_umid.principal_id
}
output "user_assigned_identity_client_id" {
  value = azurerm_user_assigned_identity.appag_umid.client_id
}
output "user_assigned_identity_tenant_id" {
  value = azurerm_user_assigned_identity.appag_umid.tenant_id
}
```

## Step-02: c11-01-azure-key-vault-input-variables.tf
```t
# Input Variables Placeholder file
```

## Step-03: c11-02-azure-key-vault-resource.tf 
```t
# Datasource-1: To get Azure Tenant Id
data "azurerm_client_config" "current" {}

# Resource-1: Azure Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                        = "${var.business_divsion}${var.environment}keyvault${random_string.myrandom.id}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enabled_for_template_deployment = true
  sku_name = "premium"
}


# Resource-2: Azure Key Vault Default Policy
resource "azurerm_key_vault_access_policy" "key_vault_default_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id
  lifecycle {
    create_before_destroy = true
  }  
  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update"
  ]
  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey"
  ]
  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
  ]
  storage_permissions = [
    "Backup", "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "SetSAS", "Update"
  ]

}


# Resource-3: Add a managed ID to your Key Vault access policy (Resource: azurerm_key_vault_access_policy)
resource "azurerm_key_vault_access_policy" "appag_key_vault_access_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appag_umid.principal_id
  secret_permissions = [
    "Get",
  ]
}


# Resource-4: Import the SSL certificate into Key Vault and store the certificate SID in a variable
resource "azurerm_key_vault_certificate" "my_cert_1" {
  depends_on = [azurerm_key_vault_access_policy.key_vault_default_policy]
  name         = "my-cert-1"
  key_vault_id = azurerm_key_vault.keyvault.id

  certificate {
    contents = filebase64("${path.module}/ssl-self-signed/httpd.pfx")
    password = "kalyan"
  }
  
  certificate_policy {
    issuer_parameters {
      name = "Unknown"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }
    lifetime_action {
      action {
        action_type = "EmailContacts"        
      }
      trigger {
        days_before_expiry = 10
      }
    }
  }

}
```

## Step-04: c11-03-azure-key-vault-outputs.tf
```t
# Output Values
output "azurerm_key_vault_certificate_id" {
  value = azurerm_key_vault_certificate.my_cert_1.id
}

output "azurerm_key_vault_certificate_secret_id" {
  value = azurerm_key_vault_certificate.my_cert_1.secret_id
}
output "azurerm_key_vault_certificate_version" {
  value = azurerm_key_vault_certificate.my_cert_1.version
}
```

## Step-05: c9-02-application-gateway-resource.tf - Locals Block
```t
# Add new variable in locals block
  ssl_certificate_name_keyvault        = "keyvault-my-cert-1"
```

## Step-06: c9-02-application-gateway-resource.tf - AG Resource - Change-1
- Comment old SSL Certificate block and use the new block associated to Key Vault
- Add User Managed Identity to Azure Application Gateway 
```t

# SSL Certificate Block
/*  ssl_certificate {
    name = local.ssl_certificate_name
    password = "kalyan"
    data = filebase64("${path.module}/ssl-self-signed/httpd.pfx")
  }*/

  ssl_certificate {
    name = local.ssl_certificate_name_keyvault
    key_vault_secret_id = azurerm_key_vault_certificate.my_cert_1.secret_id    
  }

  identity {
    identity_ids = [azurerm_user_assigned_identity.appag_umid.id]
  }  
```

## Step-07: c9-02-application-gateway-resource.tf - AG Resource - Change-2
- Update `ssl_certificate_name` name argument value with with `local.ssl_certificate_name_keyvault`
```t

# HTTPS Listener - Port 443  
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"    
    ssl_certificate_name           = local.ssl_certificate_name_keyvault    
    custom_error_configuration {
      custom_error_page_url = "${azurerm_storage_account.storage_account.primary_web_endpoint}502.html"
      status_code = "HttpStatus502"
    }
    custom_error_configuration {
      custom_error_page_url = "${azurerm_storage_account.storage_account.primary_web_endpoint}403.html"
      status_code = "HttpStatus403"
    }    
  }
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
6. AG Listeners - Review HTTPS Listener reference to Key Vault
7. AG Rules
8. AG Health Probes
9. AG Insights
```
## Step-10: Add Host Entries and Test
- Test in Firefox browser which allows the SSL exception for Self-Signed Certificates
```t
# Add Host Entries
## Linux or MacOs
sudo vi /etc/hosts

### Host Entry Template
<AG-Public-IP>  terraformguru.com

### Host Entry Template - Replace AG-Public-IP
104.45.168.153  terraformguru.com

# Test HTTP to HTTPS Redirect
http://terraformguru.com/index.html
http://terraformguru.com/app1/index.html
http://terraformguru.com/app1/metadata.html
http://terraformguru.com/app1/status.html
http://terraformguru.com/app1/hostname.html
Observation: All these should auto-redirect from HTTP to HTTPS

# Test Error Pages
1. Stop VMSS Virtual Machine Instances
2. Wait for few minutes
http://terraformguru.com/index.html
http://terraformguru.com/app1/index.html
Observation: Static error pages hosted in Static Website should be displayed 

# Access Static Error Pgaes via Static Website Endpoint
http://<STATIC-WEBSITE-ENDPOINT>/502.html
http://<STATIC-WEBSITE-ENDPOINT>/403.html


# Remove / Comment Host Entries after testing 
## Linux or MacOs
sudo vi /etc/hosts
#20.81.19.52  app1.terraformguru.com
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