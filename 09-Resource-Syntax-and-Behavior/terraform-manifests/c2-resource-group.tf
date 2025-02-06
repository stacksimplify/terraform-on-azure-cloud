# Resource-1: Azure Resource Group
resource "azurerm_resource_group" "dev-terraform-rg1" {
  name     = "dev-terraform-rg1"
  location = "East US"
}