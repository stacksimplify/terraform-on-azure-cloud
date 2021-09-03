---
title: Terraform Meta-Argument for_each and For Loops 
description: Create multiple resources in Terraform and for_each
---

## Step-00: Introduction
- Terraform Meta-Argument [for_each](https://www.terraform.io/docs/language/meta-arguments/for_each.html) for Azure Web Linux VMs and VM NIC
- Terraform Meta-Argument [for_each](https://www.terraform.io/docs/language/meta-arguments/for_each.html) for Azure Standard Load Balancer
- [Terraform for Expressions](https://www.terraform.io/docs/language/expressions/for.html)
- [Terraform lookup function](https://www.terraform.io/docs/language/functions/lookup.html)
- [Terraform keys function](https://www.terraform.io/docs/language/functions/keys.html)
- [Terraform values function](https://www.terraform.io/docs/language/functions/values.html)

### Changes as part of this Demo
- We are going to make change to following files
1. c7-01-web-linuxvm-input-variables.tf
2. terraform.tfvars
3. c7-03-web-linuxvm-network-interface.tf
4. c7-05-web-linuxvm-resource.tf
5. c7-06-web-linuxvm-outputs.tf
6. c9-02-web-loadbalancer-resource.tf
7. c9-04-web-loadbalancer-inbound-nat-rules.tf

### Bastion Host (Optional Changes)
- Additional Optional Changes to bastion host. As we are enabling Inbound NAT via LB bastion host in this usecase or demo is optional. 
- If you want you can comment all the code in below listed files to not to have Bastion Host created. 
- I am going to leave them as-is without commenting them. 
1. c8-01-bastion-host-input-variables.tf
2. c8-02-bastion-host-linuxvm.tf
3. c8-03-move-ssh-key-to-bastion-host.tf
4. c8-05-bastion-outputs.tf

### Additional Note for reference
1. Meta-Argument count - Terraform Function element()
2. Meta-Argument for_each with maps - Terraform Function lookup()


## Step-01: c7-01-web-linuxvm-input-variables.tf
```t
# Web Linux VM Instance Count
variable "web_linuxvm_instance_count" {
  description = "Web Linux VM Instance Count"
  type = map(string)
  default = {
    "vm1" = "1022",
    "vm2" = "2022"
  }
}
```

## Step-02: terraform.tfvars
```t
web_linuxvm_instance_count = {  
    "vm1" = "1022",
    "vm2" = "2022"
  }
```

## Step-03: c7-03-web-linuxvm-network-interface.tf
```t
# Resource-2: Create Network Interface
resource "azurerm_network_interface" "web_linuxvm_nic" {
  for_each = var.web_linuxvm_instance_count
  name                = "${local.resource_name_prefix}-web-linuxvm-nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "web-linuxvm-ip-1"
    subnet_id                     = azurerm_subnet.websubnet.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id = azurerm_public_ip.web_linuxvm_publicip.id 
  }
}
```

## Step-04: c7-05-web-linuxvm-resource.tf
```t
# Resource: Azure Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "web_linuxvm" {
  for_each = var.web_linuxvm_instance_count
  name = "${local.resource_name_prefix}-web-linuxvm-${each.key}"
  #computer_name = "web-linux-vm"  # Hostname of the VM (Optional)
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_DS1_v2"
  admin_username = "azureuser"
  network_interface_ids = [azurerm_network_interface.web_linuxvm_nic[each.key].id]
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

## Step-05: c7-06-web-linuxvm-outputs.tf
```t
# Different Outputs with Terraform For Loops

# Output List - Single Input to for loop
output "web_linuxvm_private_ip_address_list" {
  description = "Web Linux Virtual Machine Private IP"
  value = [for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.private_ip_address ]   
}

# Output Map  - Single Input to for loop
output "web_linuxvm_private_ip_address_map" {
  description = "Web Linux Virtual Machine Private IP"
  value = {for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.name => vm.private_ip_address }
}

# Terraform keys() function: keys takes a map and returns a list containing the keys from that map.
output "web_linuxvm_private_ip_address_keys_function" {
  description = "Web Linux Virtual Machine Private IP"
  value = keys({for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.name => vm.private_ip_address })
}
# Terraform values() function: values takes a map and returns a list containing the values of the elements in that map.
output "web_linuxvm_private_ip_address_values_function" {
  description = "Web Linux Virtual Machine Private IP"
  value = values({for vm in azurerm_linux_virtual_machine.web_linuxvm: vm.name => vm.private_ip_address })
}

# Output List - Two Inputs to for loop (here vm is Iterator like "i")
output "web_linuxvm_network_interface_id_list" {
  description = "Web Linux VM Network Interface ID"
  value = [for vm, nic in azurerm_network_interface.web_linuxvm_nic: nic.id]
}

# Output Map  - Two Inputs to for loop (here vm is Iterator like "i")
output "web_linuxvm_network_interface_id_map" {
  description = "Web Linux VM Network Interface ID"
  value = {for vm, nic in azurerm_network_interface.web_linuxvm_nic: vm => nic.id}
}
```

## Step-06: c9-02-web-loadbalancer-resource.tf
```t
# Resource-6: Associate Network Interface and Standard Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb_associate" {
  for_each = var.web_linuxvm_instance_count
  network_interface_id    = azurerm_network_interface.web_linuxvm_nic[each.key].id
  ip_configuration_name   = azurerm_network_interface.web_linuxvm_nic[each.key].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id
}
```

## Step-07: 9-04-web-loadbalancer-inbound-nat-rules.tf
```t
# Azure LB Inbound NAT Rule
resource "azurerm_lb_nat_rule" "web_lb_inbound_nat_rule_22" {
  depends_on = [azurerm_linux_virtual_machine.web_linuxvm  ]
  for_each = var.web_linuxvm_instance_count
  name = "${each.key}-ssh-${each.value}-vm-22"
  protocol = "Tcp"
  frontend_port = each.value
  backend_port = 22
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.web_lb.id
}

# Associate LB NAT Rule and VM Network Interface
resource "azurerm_network_interface_nat_rule_association" "web_nic_nat_rule_associate" {
  for_each = var.web_linuxvm_instance_count
  network_interface_id =  azurerm_network_interface.web_linuxvm_nic[each.key].id 
  ip_configuration_name = azurerm_network_interface.web_linuxvm_nic[each.key].ip_configuration[0].name 
  nat_rule_id = azurerm_lb_nat_rule.web_lb_inbound_nat_rule_22[each.key].id
}

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

# Verify Resources - Web Linux VM (2 Virtual Machines)
1. Verify Network Interface created for 2 Web Linux VMs
2. Verify 2 Web Linux VMs
3. Verify Network Security Groups associated with VM (web Subnet NSG)
4. View Topology at Web Linux VM -> Networking
5. Verify if only private IP associated with Web Linux VM

# Verify Resources - Bastion Host
1. Verify Bastion Host VM Public IP
2. Verify Bastion Host VM Network Interface
3. Verify Bastion VM
4. Verify Bastion VM -> Networking -> NSG Rules
5. Verify Bastion VM Topology

# Connect to Bastion Host VM
1. Connect to Bastion Host Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Host-LinuxVM-PublicIP>
sudo su - 
cd /tmp
ls 
2. terraform-azure.pem file should be present in /tmp directory

# Connect to Web Linux VM using Bastion Host VM
1. Connect to Web Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PrivateIP>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/app1
ls -lrt
exit
exit

# Verify Standard Load Balancer Resources
1. Verify Public IP Address for Standard Load Balancer
2. Verify Standard Load Balancer (SLB) Resource
3. Verify SLB - Frontend IP Configuration
4. Verify SLB - Backend Pools
5. Verify SLB - Health Probes
6. Verify SLB - Load Balancing Rules
7. Verify SLB - Insights
8. Verify SLB - Diagnose and Solve Problems

# Access Application
http://<LB-Public-IP>
http://<LB-Public-IP>/app1/index.html
http://<LB-Public-IP>/app1/metadata.html

# Curl Test
curl http://<LB-Public-IP>
```


## Step-10: Verify Inbound NAT Rules for Port 22
```t
# VM1 - Verify Inbound NAT Rule
ssh -i ssh-keys/terraform-azure.pem -p 1022 azureuser@<LB-Public-IP>

# VM2 - Verify Inbound NAT Rule
ssh -i ssh-keys/terraform-azure.pem -p 2022 azureuser@<LB-Public-IP>
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
- When your Linux VM NIC is associated with Security Group, the deletion criteria has issues with Azure Provider
- Due to that below related errors might come. This is provider related bug. 
- In our usecase we didn't associate any NSG to VMs directly, we are using subnet level NSG, so this error will not come for us. 
- Even this error comes when we associate NSG with VM NIC, just go to Azure Portal Console and delete that resource group so that all associated resources will be deleted. 
```t
azurerm_public_ip.bastion_host_publicip: Still destroying... [id=/subscriptions/82808767-144c-4c66-a320-...Addresses/hr-dev-bastion-host-publicip, 10s elapsed]
azurerm_subnet.bastionsubnet: Still destroying... [id=/subscriptions/82808767-144c-4c66-a320-...vnet/subnets/hr-dev-vnet-bastionsubnet, 10s elapsed]
azurerm_subnet.bastionsubnet: Destruction complete after 10s
azurerm_public_ip.bastion_host_publicip: Destruction complete after 12s
╷
│ Error: Error waiting for removal of Backend Address Pool Association for NIC "hr-dev-linuxvm-nic" (Resource Group "hr-dev-rg"): Code="OperationNotAllowed" Message="Operation 'startTenantUpdate' is not allowed on VM 'hr-dev-linuxvm1' since the VM is marked for deletion. You can only retry the Delete operation (or wait for an ongoing one to complete)." Details=[]
│
```