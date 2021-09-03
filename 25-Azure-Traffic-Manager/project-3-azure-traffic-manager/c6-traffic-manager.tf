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
