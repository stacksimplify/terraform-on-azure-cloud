# Environment Name
environment = "qa"

# Virtual Network Variables
vnet_name = "vnet"
vnet_address_space = ["10.2.0.0/16"]

web_subnet_name = "websubnet"
web_subnet_address = ["10.2.1.0/24"]

app_subnet_name = "appsubnet"
app_subnet_address = ["10.2.11.0/24"]

db_subnet_name = "dbsubnet"
db_subnet_address = ["10.2.21.0/24"]

bastion_subnet_name = "bastionsubnet"
bastion_subnet_address = ["10.2.100.0/24"]

# Web Linux VM Variables
web_linuxvm_size = "Standard_DS1_v2"
web_linuxvm_admin_user = "azureuser"