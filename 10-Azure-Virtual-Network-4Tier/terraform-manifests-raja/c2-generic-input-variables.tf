
variable "business_divsion" {
  description = "BU"
  type = string
  default = "sap"
}

variable "environment" {
  description = "Environment"
  type = string
  default = "dev"
}

variable "resource_group_name" {
  description = "Azure RG"
  type = string
  default = "rg-default"
}

variable "resource_group_location" {
  description = "Azure Location"
  type = string
  default = "westeurope"
}