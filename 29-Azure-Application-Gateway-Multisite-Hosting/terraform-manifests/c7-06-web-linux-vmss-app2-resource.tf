# Locals Block for custom data
locals {
app2_webvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
#sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd  
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo chmod -R 777 /var/www/html 
sudo echo "Welcome to stacksimplify - WebVM App2 - VM Hostname: $(hostname)" > /var/www/html/index.html
sudo mkdir /var/www/html/app2
sudo echo "Welcome to stacksimplify - WebVM App2 - VM Hostname: $(hostname)" > /var/www/html/app2/hostname.html
sudo echo "Welcome to stacksimplify - WebVM App2 - App Status Page" > /var/www/html/app2/status.html
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(60, 179, 113);"> <h1>Welcome to Stack Simplify - WebVM APP-2 </h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/app2/index.html
sudo curl -H "Metadata:true" --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/app2/metadata.html
CUSTOM_DATA  
}


# Resource: Azure Linux Virtual Machine Scale Set - App2
resource "azurerm_linux_virtual_machine_scale_set" "app2_web_vmss" {
  name                = "${local.resource_name_prefix}-app2-web-vmss"
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
    name    = "app2-web-vmss-nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.app2_web_vmss_nsg.id
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.websubnet.id  
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.web_ag.backend_address_pool[1].id]            
    }
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-app1-script.sh")      
  custom_data = base64encode(local.app2_webvm_custom_data)  
}
  

