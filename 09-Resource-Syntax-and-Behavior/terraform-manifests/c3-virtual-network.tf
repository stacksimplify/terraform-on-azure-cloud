# Resource-2: Create Virtual Network
resource "azurerm_virtual_network" "dev-terraform-vnet" {
  name                = "dev-terraform-vnet-1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.dev-terraform-rg1.location
  resource_group_name = azurerm_resource_group.dev-terraform-rg1.name
  tags = {
    "Name" = "dev-terraform-vnet-1"
    #"Environment" = "Dev"  # Uncomment during Step-10
  }
}

# Resource-3: Create Subnet
resource "azurerm_subnet" "dev-terraform-subnet-1" {
  name                 = "dev-terraform-subnet"
  resource_group_name  = azurerm_resource_group.dev-terraform-rg1.name
  virtual_network_name = azurerm_virtual_network.dev-terraform-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Resource-4: Create Public IP Address
resource "azurerm_public_ip" "dev-terraform-publicip" {
  name                = "dev-terraform-publicip-1"
  resource_group_name = azurerm_resource_group.dev-terraform-rg1.name
  location            = azurerm_resource_group.dev-terraform-rg1.location
  allocation_method   = "Static"
  tags = {
    environment = "Dev"
  }
}

# Resource-5: Create Network Interface
resource "azurerm_network_interface" "dev-terraform-vmnic-1" {
  name                = "dev-terraform-vmnic"
  location            = azurerm_resource_group.dev-terraform-rg1.location
  resource_group_name = azurerm_resource_group.dev-terraform-rg1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev-terraform-subnet-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dev-terraform-publicip.id
  }
}

