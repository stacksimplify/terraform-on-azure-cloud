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
