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

# Locals Block for Static html files for Azure Application Gateway 
locals {
  pages = ["index.html", "error.html", "502.html", "403.html"]
}

# Resource-2: Add Static html files to blob storage
resource "azurerm_storage_blob" "static_container_blob" {
  for_each = toset(local.pages)
  name                   = each.value
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source = "${path.module}/custom-error-pages/${each.value}"
}
