# Terraform Settings Block
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.0" # Optional but recommended in production
    }    
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = "cd10533a-c677-4d76-bda9-b7234d3c33de"
}

# Create Resource Group 
resource "azurerm_resource_group" "dev-terraform-rg1" {
  location = "eastus"
  name = "dev-terraform-rg1"  
}
