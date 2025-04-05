terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.26.0"
    }
  random = {
      source = "hashicorp/random"
      version = "3.7.1"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = "08f255e4-6731-4c51-a43f-e1e5038f69ba" 
}