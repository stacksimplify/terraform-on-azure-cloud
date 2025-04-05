locals {
  owners = var.business_divsion
  environment = var.environment
  common_tags = {
    owners = local.owners
    environment = local.environment
  }
  resource_name_prefix = "${var.business_divsion}-${var.environment}"
}