# Locals Block for custom data
locals {
webvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
#sudo yum update -y
# Stop Firewall and Disable it
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# Java App Install
sudo yum -y install java-11-openjdk
sudo yum -y install telnet
sudo yum -y install mysql
mkdir /home/azureuser/app3-usermgmt && cd /home/azureuser/app3-usermgmt
wget https://github.com/stacksimplify/temp1/releases/download/1.0.0/usermgmt-webapp.war -P /home/azureuser/app3-usermgmt 
export DB_HOSTNAME=${azurerm_mysql_server.mysql_server.fqdn}
export DB_PORT=3306
export DB_NAME=${azurerm_mysql_database.webappdb.name}
export DB_USERNAME="${azurerm_mysql_server.mysql_server.administrator_login}@${azurerm_mysql_server.mysql_server.fqdn}"
export DB_PASSWORD=${azurerm_mysql_server.mysql_server.administrator_login_password}
java -jar /home/azureuser/app3-usermgmt/usermgmt-webapp.war > /home/azureuser/app3-usermgmt/ums-start.log &
CUSTOM_DATA  
}


# Resource: Azure Linux Virtual Machine Scale Set - App1
resource "azurerm_linux_virtual_machine_scale_set" "web_vmss" {
  # 1. Create VMSS only if Java App related DB Schema "webappdb" is created in MySQL Server
  # 2. Only create VMSS if DB is ready with Virtual Network Rule so connection for Java App can be established to DB
  depends_on = [azurerm_mysql_database.webappdb, azurerm_mysql_virtual_network_rule.mysql_virtual_network_rule] 
  name                = "${local.resource_name_prefix}-web-vmss"
  #computer_name_prefix = "vmss-app1" # if name argument is not valid one for VMs, we can use this for VM Names
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh-keys/terraform-azure.pub")
  }

  source_image_reference {
    publisher = "RedHat"
    offer = "RHEL"
    sku = "83-gen2"
    version = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  upgrade_mode = "Automatic"
  
  network_interface {
    name    = "web-vmss-nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.web_vmss_nsg.id
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.websubnet.id  
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.web_ag.backend_address_pool[0].id]            
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.webvm_custom_data)  
}
  

