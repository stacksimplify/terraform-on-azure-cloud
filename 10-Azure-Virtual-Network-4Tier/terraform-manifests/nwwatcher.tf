resource "azurerm_network_watcher" "default" {
  location            = "eastus"
  name                = "NetworkWatcher_eastus"
  resource_group_name = "NetworkWatcherRG"
  tags                = {}

  timeouts {}
}