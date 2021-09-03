---
title: Azure Linux VM using Terraform
description: Create Azure Linux VM using Terraform
---

## Step-00: Introduction
- We are going to create following Azure Resources
1. azurerm_public_ip
2. azurerm_network_interface
3. azurerm_network_security_group
4. azurerm_network_interface_security_group_association
5. Terraform Local Block for Security Rule Ports
6. Terraform `for_each` Meta-argument
7. azurerm_network_security_rule
8. Terraform Local Block for defining custom data to Azure Linux Virtual Machine
9. azurerm_linux_virtual_machine
10. Terraform Outputs for above listed Azured Resources 
11. Terraform Functions
- [file](https://www.terraform.io/docs/language/functions/file.html)
- [filebase64](https://www.terraform.io/docs/language/functions/filebase64.html)
- [base64encode](https://www.terraform.io/docs/language/functions/base64encode.html)

## Pre-requisite Note: Create SSH Keys for Azure Linux VM
```t
# Create Folder
cd terraform-manifests/
mkdir ssh-keys

# Create SSH Key
cd ssh-ekys
ssh-keygen \
    -m PEM \
    -t rsa \
    -b 4096 \
    -C "azureuser@myserver" \
    -f terraform-azure.pem 
Important Note: If you give passphrase during generation, during everytime you login to VM, you also need to provide passphrase.

# List Files
ls -lrt ssh-keys/

# Files Generated after above command 
Public Key: terraform-azure.pem.pub -> Rename as terraform-azure.pub
Private Key: terraform-azure.pem

# Permissions for Pem file
chmod 400 terraform-azure.pem
```

## Step-01: c7-01-web-linuxvm-input-variables.tf
- Place holder file for Linux VM Input Variables. 

## Step-02: c7-02-web-linuxvm-publicip.tf
```t
# Resource-1: Create Public IP Address
resource "azurerm_public_ip" "web_linuxvm_publicip" {
  name                = "${local.resource_name_prefix}-linuxvm-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
  #domain_name_label = "app1-vm-${random_string.myrandom.id}"
}
```

## Step-03: c7-03-web-linuxvm-network-interface.tf
```t
# Resource-2: Create Network Interface
resource "azurerm_network_interface" "web_linuxvm_nic" {
  name                = "${local.resource_name_prefix}-web-linuxvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "web-linuxvm-ip-1"
    subnet_id                     = azurerm_subnet.websubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.web_linuxvm_publicip.id 
  }
}
```

## Step-04: c7-04-web-linuxvm-network-security-group.tf
```t

# Resource-3 (Optional): Create Network Security Group and Associate to Linux VM Network Interface
# Resource-1: Create Network Security Group (NSG)
resource "azurerm_network_security_group" "web_vmnic_nsg" {
  name                = "${azurerm_network_interface.web_linuxvm_nic.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-2: Associate NSG and Linux VM NIC
resource "azurerm_network_interface_security_group_association" "web_vmnic_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.web_vmnic_nsg_rule_inbound]
  network_interface_id      = azurerm_network_interface.web_linuxvm_nic.id
  network_security_group_id = azurerm_network_security_group.web_vmnic_nsg.id
}

# Resource-3: Create NSG Rules
## Locals Block for Security Rules
locals {
  web_vmnic_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "120" : "22"
  } 
}
## NSG Inbound Rule for WebTier Subnets
resource "azurerm_network_security_rule" "web_vmnic_nsg_rule_inbound" {
  for_each = local.web_vmnic_inbound_ports_map
  name                        = "Rule-Port-${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value 
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_vmnic_nsg.name
}
```

## Step-05: c7-05-web-linuxvm-resource.tf
- We have two options to define `custom_data` to Azure Linux VM 
- **Option-1:** Using file as input (shell script file or cloud-init txt file)
- **Option-2:** Define the code in Terraform locals block
- We will review both options and choose `option-2` for implementation.
- Commented code will be available in `azurerm_linux_virtual_machine` to use `option-1` too.
```t
# Locals Block for custom data
locals {
webvm_custom_data = <<CUSTOM_DATA
#!/bin/sh
#!/bin/sh
#sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd  
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo chmod -R 777 /var/www/html 
sudo echo "Welcome to stacksimplify - WebVM App1 - VM Hostname: $(hostname)" > /var/www/html/index.html
sudo mkdir /var/www/html/app1
sudo echo "Welcome to stacksimplify - WebVM App1 - VM Hostname: $(hostname)" > /var/www/html/app1/hostname.html
sudo echo "Welcome to stacksimplify - WebVM App1 - App Status Page" > /var/www/html/app1/status.html
sudo echo '<!DOCTYPE html> <html> <body style="background-color:rgb(250, 210, 210);"> <h1>Welcome to Stack Simplify - WebVM APP-1 </h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>' | sudo tee /var/www/html/app1/index.html
sudo curl -H "Metadata:true" --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2020-09-01" -o /var/www/html/app1/metadata.html
CUSTOM_DATA  
}


# Resource: Azure Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "web_linuxvm" {
  name = "${local.resource_name_prefix}-web-linuxvm"
  #computer_name = "web-linux-vm"  # Hostname of the VM (Optional)
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_DS1_v2"
  admin_username = "azureuser"
  network_interface_ids = [ azurerm_network_interface.web_linuxvm_nic.id ]
  admin_ssh_key {
    username = "azureuser"
    public_key = file("${path.module}/ssh-keys/terraform-azure.pub")
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "RedHat"
    offer = "RHEL"
    sku = "83-gen2"
    version = "latest"
  }
  #custom_data = filebase64("${path.module}/app-scripts/redhat-webvm-script.sh")    
  custom_data = base64encode(local.webvm_custom_data)  

}
```

## Step-06: c7-06-web-linuxvm-outputs.tf
```t
# Public IP Outputs

## Public IP Address
output "web_linuxvm_public_ip" {
  description = "Web Linux VM Public Address"
  value = azurerm_public_ip.web_linuxvm_publicip.ip_address
}


# Network Interface Outputs
## Network Interface ID
output "web_linuxvm_network_interface_id" {
  description = "Web Linux VM Network Interface ID"
  value = azurerm_network_interface.web_linuxvm_nic.id
}
## Network Interface Private IP Addresses
output "web_linuxvm_network_interface_private_ip_addresses" {
  description = "Web Linux VM Private IP Addresses"
  value = [azurerm_network_interface.web_linuxvm_nic.private_ip_addresses]
}

# Linux VM Outputs

## Virtual Machine Public IP
output "web_linuxvm_public_ip_address" {
  description = "Web Linux Virtual Machine Public IP"
  value = azurerm_linux_virtual_machine.web_linuxvm.public_ip_address
}


## Virtual Machine Private IP
output "web_linuxvm_private_ip_address" {
  description = "Web Linux Virtual Machine Private IP"
  value = azurerm_linux_virtual_machine.web_linuxvm.private_ip_address
}
## Virtual Machine 128-bit ID
output "web_linuxvm_virtual_machine_id_128bit" {
  description = "Web Linux Virtual Machine ID - 128-bit identifier"
  value = azurerm_linux_virtual_machine.web_linuxvm.virtual_machine_id
}
## Virtual Machine ID
output "web_linuxvm_virtual_machine_id" {
  description = "Web Linux Virtual Machine ID "
  value = azurerm_linux_virtual_machine.web_linuxvm.id
}
```

## Step-07: terraform.tfvars
```t
business_divsion = "hr"
environment = "dev"
resource_group_name = "rg"
resource_group_location = "eastus"
vnet_name = "vnet"
vnet_address_space = ["10.1.0.0/16"]

web_subnet_name = "websubnet"
web_subnet_address = ["10.1.1.0/24"]

app_subnet_name = "appsubnet"
app_subnet_address = ["10.1.11.0/24"]

db_subnet_name = "dbsubnet"
db_subnet_address = ["10.1.21.0/24"]

bastion_subnet_name = "bastionsubnet"
bastion_subnet_address = ["10.1.100.0/24"]
```

## Step-08: Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

## Step-09: Verify Resources
```t
# Verify Resources - Virtual Network
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnets (Web, App, DB, Bastion)
4. Azure Network Security Groups (Web, App, DB, Bastion)
5. View the topology
6. Verify Terraform Outputs in Terraform CLI

# Verify Resources - Web Linux VM 
1. Verify Public IP created for Web Linux VM
2. Verify Network Interface created for Web Linux VM
3. Verify Web Linux VM
4. Verify Network Security Groups associated with VM (web Subnet NSG and NIC NSG)
5. View Topology at Web Linux VM -> Networking
6. Connect to Web Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PublicIP>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/app1
ls -lrt
exit
exit

7. Access Sample Application
http://<PUBLIC-IP>/
http://<PUBLIC-IP>/app1/index.html
http://<PUBLIC-IP>/app1/hostname.html
http://<PUBLIC-IP>/app1/status.html
http://<PUBLIC-IP>/app1/metadata.html
```

## Step-10: Comment NSG associated with VM
```t
# Comment code in c7-04-web-linuxvm-network-security-group.tf
NSG associated with Web Linux VM NIC is commented

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify NSG associated with VM
1. Verify Network Security Groups associated with VM (web Subnet NSG only)
2. Access Application
http://<PUBLIC-IP>/app1/metadata.html
```

## Step-11: Delete Resources
```t
# Delete Resources
terraform destroy 
[or]
terraform apply -destroy -auto-approve

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```

## Step-12: Additional Cautionary Note
- If we don't disassociate the NSG associated with VM first before destroying resources and directly destroy all resources we might face the below error. 
- At that point we need to manually delete the resource group directly in Azure Portal Console
- This is due to Terraform Azure Provider not able to handle dependencies effectively
```t
# Destroy Resources
terraform destroy -auto-approve

# Manually Delete the RG
Login to Azure Mgmt Console 
Go to Resource Groups -> hr-dev-rg -> Delete

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```
### Error Log
```log
│ Error: Error waiting for update of Network Interface "hr-dev-linuxvm-nic" (Resource Group "hr-dev-rg"): Code="OperationNotAllowed" Message="Operation 'startTenantUpdate' is not allowed on VM 'hr-dev-linuxvm1' since the VM is marked for deletion. You can only retry the Delete operation (or wait for an ongoing one to complete)." Details=[]
│ 
│ 
```