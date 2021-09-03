---
title: Azure Virtual Machine Scale Sets Autoscaling with Terraform
description: Create Azure Virtual Machine Scale Sets Autoscaling with Terraform
---

## Pre-requisite: Learn VMSS Autoscaling Concept using Azure Portal
1. Create VMSS
2. Create Autoscaling Default Profile
  - Percentage CPU Rule
  - Available Memory Bytes Rule
  - LB SYN Count Rule
3. Create Autoscaling Recurrence Profile - Weekdays
4. Create Autoscaling Recurrence Profile - Weekends
5. Create Autoscaling Fixed Profile

```t
Resource: azurerm_monitor_autoscale_setting
- Notification Block
- Profile Block-1: Default Profile
  1. Capacity Block
  2. Percentage CPU Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when CPU usage is greater than 75%
    2. Scale-In Rule: Decrease VMs by 1when CPU usage is lower than 25%
  3. Available Memory Bytes Metric Rules
    1. Scale-Up Rule: Increase VMs by 1 when Available Memory Bytes is less than 1GB in bytes
    2. Scale-In Rule: Decrease VMs by 1 when Available Memory Bytes is greater than 2GB in bytes
  4. LB SYN Count Metric Rules (JUST FOR firing Scale-Up and Scale-In Events for Testing and also knowing in addition to current VMSS Resource, we can also create Autoscaling rules for VMSS based on other Resource usage like Load Balancer)
    1. Scale-Up Rule: Increase VMs by 1 when LB SYN Count is greater than 10 Connections (Average)
    2. Scale-Up Rule: Decrease VMs by 1 when LB SYN Count is less than 10 Connections (Average)    
```

## Step-00: Introduction
- VMSS Autoscaling
1. Default Profile
2. Recurrence Profile
3. Fixed Profile
- Each Profile will have following Rules
1. `Percentage CPU` Increase and Decrease Rule
2. `Available Memory Bytes` Increase and Decrease Rule
3. LB `SYN Count` Increase and Decrease Rule



## Update Files
- c8-02-bastion-host-linuxvm.tf: Add Bastion Custom Data

### New Files: Web Linux VMSS
1. c7-05-web-linux-vmss-autoscaling-default-profile.tf
2. c7-06-web-linux-vmss-autoscaling-default-and-recurrence-profiles.tf
3. c7-07-web-linux-vmss-autoscaling-default-recurrence-fixed-profiles.tf


## Step-01: c8-02-bastion-host-linuxvm.tf
- Add Custom Data for Bastion Host which will install HTTPD related binaries. 
- This will install the Apache Bench tool for load testing.
- This Apache Bench helps us to generate huge load on our Application to trigger Scale-Out and Scale-In events for Autoscaling
```t
# Locals Block for custom data
locals {
bastion_host_custom_data = <<CUSTOM_DATA
#!/bin/sh
#sudo yum update -y
sudo yum install -y httpd
sudo systemctl enable httpd
sudo systemctl start httpd  
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo yum install -y telnet
sudo chmod -R 777 /var/www/html 
sudo echo "Welcome to stacksimplify - Bastion Host - VM Hostname: $(hostname)" > /var/www/html/index.html
CUSTOM_DATA  
}


# Resource-1: Create Public IP Address
resource "azurerm_public_ip" "bastion_host_publicip" {
  name                = "${local.resource_name_prefix}-bastion-host-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
}

# Resource-2: Create Network Interface
resource "azurerm_network_interface" "bastion_host_linuxvm_nic" {
  name                = "${local.resource_name_prefix}-bastion-host-linuxvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "bastion-host-ip-1"
    subnet_id                     = azurerm_subnet.bastionsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.bastion_host_publicip.id 
  }
}

# Resource-3: Azure Linux Virtual Machine - Bastion Host
resource "azurerm_linux_virtual_machine" "bastion_host_linuxvm" {
  name = "${local.resource_name_prefix}-bastion-linuxvm"
  #computer_name = "bastionlinux-vm"  # Hostname of the VM (Optional)
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  size = "Standard_DS1_v2"
  admin_username = "azureuser"
  network_interface_ids = [ azurerm_network_interface.bastion_host_linuxvm_nic.id ]
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
  custom_data = base64encode(local.bastion_host_custom_data)  
}
```

## Step-02: c7-05-web-linux-vmss-autoscaling-default-profile.tf
- Create Base Autoscaling Resource without any profiles
```t
resource "azurerm_monitor_autoscale_setting" "web_vmss_autoscale" {
  name                = "${local.resource_name_prefix}-web-vmss-autoscale-profiles"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_vmss.id
  # Notification Block  
  notification {
      email {
        send_to_subscription_administrator    = true
        send_to_subscription_co_administrator = true
        custom_emails                         = ["myadminteam@ourorg.com"]
      }
    }    
}    
```

## Step-03: Profile-1: Default Profile - Percentage CPU Metric
- File: c7-05-web-linux-vmss-autoscaling-default-profile.tf
```t
################################################################################
################################################################################
#######################  Profile-1: Default Profile  ###########################
################################################################################
################################################################################    
# Profile-1: Default Profile 
  profile {
    name = "default"
  # Capacity Block     
    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Up 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
    }
###########  END: Percentage CPU Metric Rules   ###########    
```

## Step-04: Profile-1: Default Profile - Available Memory Bytes Metric
```t
###########  START: Available Memory Bytes Metric Rules  ###########    
  ## Scale-Up 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }            
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1073741824 # Increase 1 VM when Memory In Bytes is less than 1GB
      }
    }

  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }        
      metric_trigger {
        metric_name        = "Available Memory Bytes"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2147483648 # Decrease 1 VM when Memory In Bytes is Greater than 2GB
      }
    }
###########  END: Available Memory Bytes Metric Rules  ###########  
```

## Step-05: Profile-1: Default Profile - LB SYN Count Metric
```t
###########  START: LB SYN Count Metric Rules - Just to Test scale-in, scale-out  ###########    
  ## Scale-Up 
    rule {
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id 
        metric_namespace   = "Microsoft.Network/loadBalancers"        
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 10 # 10 requests to an LB
      }
    }
  ## Scale-In 
    rule {
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT5M"
      }      
      metric_trigger {
        metric_name        = "SYNCount"
        metric_resource_id = azurerm_lb.web_lb.id
        metric_namespace   = "Microsoft.Network/loadBalancers"                
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
    }
###########  END: LB SYN Count Metric Rules  ###########    
  } # End of Profile-1

} # End of Auto Scale Resource
```

## Step-06: Execute Terraform Commands
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

## Step-07: Verify Resources
```t
# Other Resources (Untouched)
1. Resource Group 
2. VNETs and Subnets
3. Bastion Host Linux VM

# VMSS Resource
1. Verify the VM Instances in VMSS Resources
2. 2 VM Instances should be created as per Capacity Block from Profile-1: Default Profile
  # Capacity Block     
    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }
3. Verify the Autoscaling Policy in Scaling Tab of VMSS Resource    
```

## Step-08: Test Scale-Out and Scale-In scenarios
```t
# Connect to Bastion Host Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Host-LinuxVM-PublicIP>
sudo su - 

# Run the Load Test using Apache Bench
ab -k -t 1200 -n 9050000 -c 100 http://<Web-LB-Public-IP>/index.html
ab -k -t 1200 -n 9050000 -c 100 http://52.149.253.66/index.html

# Verify Scale-Out Event
1. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Instances
2. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Configure tab -> Open LB Connection Rule
3. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Run History Tab
4. Scale-Out Observation: A new VM should be created in VM Instances Tab of VMSS 

# Wait for 10 to 15 Minutes
- Wait for 10 to 15 minutes for "Scale-In" Event to Trigger

# Verify Scale-In Event
1. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Instances
2. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Configure tab -> Open LB Connection Rule
3. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Run History Tab
4. Scale-In Observation: 1 VM should be deleted in VM Instances Tab of VMSS and should come down to value present in capacity block (capacity.minimum = 2 VMs)
```

## Step-09: c7-05-web-linux-vmss-autoscaling-default-profile.tf
- Comment All code in c7-05.
- In c7-06, we will add profile-2 and profile-3

## Step-10: Autoscaling Profile-2: Recurrence Profiles: Weekday Profile
- c7-06-web-linux-vmss-autoscaling-default-and-recurrence-profiles.tf
```t
## Major Changes in this Block
# 1. Capacity Block Values Change - Week Days (Minimum = 4, default = 4, Maximum = 20)
# 2. Recurrence Block for Week Days
# Profile-2: Recurrence Profile - Week Days
  profile {
    name = "profile-2-weekdays"
  # Capacity Block     
    capacity {
      default = 4
      minimum = 4
      maximum = 20
    }
  # Recurrence Block for Week Days (5 days)
    recurrence {
      timezone = "India Standard Time"
      days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours = [0]
      minutes = [0]      
    }  
##########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      .....
      REST ALL SAME DEFAULT Profile
      .....
      .....
}      
```
## Step-11: Autoscaling Profile-3: Recurrence Profiles: Weekend Profile
```t
## Major Changes in this Block
# 1. Capacity Block Values Change - Weekends (Minimum = 3, default = 3, Maximum = 20)
# 2. Recurrence Block for Weekends
# Profile-2: Recurrence Profile - Weekends
  profile {
    name = "profile-3-weekends"
  # Capacity Block     
    capacity {
      default = 3
      minimum = 3
      maximum = 6
    }
  # Recurrence Block for Weekends (2 days)
    recurrence {
      timezone = "India Standard Time"
      days = ["Saturday", "Sunday"]
      hours = [0]
      minutes = [0]      
    }    
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      .....
      REST ALL SAME DEFAULT Profile
      .....
      .....
}        
```


## Step-12: Apply and Verify VMSS Resource - Autoscaling Profile-2 and 3
```t
# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply 
terraform apply -auto-approve

# Verify VMSS Resource
1. Verify the VM Instances in VMSS Resources
2. 3 or 4 VM Instances should be created as per Capacity Block from Profile-2 or 3 based on the day you are testing 
  # Capacity Block     
    capacity {
      default = 3 or 4 
      minimum = 3 or 4
      maximum = 6
    }
3. Verify the Autoscaling Policy in Scaling Tab of VMSS Resource 
4. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -
  a. Profile-1: Default Profile
  b. Profile-2: Weekday Profile
  c. Profile-3: Weekend Profile
```

## Step-13: Test Scale-Out and Scale-In scenarios
```t
# Connect to Bastion Host Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Host-LinuxVM-PublicIP>
sudo su - 

# Run the Load Test using Apache Bench
ab -k -t 1200 -n 9050000 -c 100 http://<Web-LB-Public-IP>/index.html
ab -k -t 1200 -n 9050000 -c 100 http://52.149.253.66/index.html

# Verify Scale-Out Event
1. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Instances
2. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Configure tab -> Open LB Connection Rule
3. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Run History Tab
4. Scale-Out Observation: A new VM should be created in VM Instances Tab of VMSS 

# Wait for 10 to 15 Minutes
- Wait for 10 to 15 minutes for "Scale-In" Event to Trigger

# Verify Scale-In Event
1. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Instances
2. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Configure tab -> Open LB Connection Rule
3. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Run History Tab
4. Scale-In Observation: 1 VM should be deleted in VM Instances Tab of VMSS and should come down to value present in capacity block (capacity.minimum = 3 or 4 VMs)
```


## Step-14: c7-06-web-linux-vmss-autoscaling-default-and-recurrence-profiles.tf
- Comment All code in c7-06.
- In c7-07 we will add profile-4 with `fixed_date` block as the day we are testing (Current Day)

## Step-15: Autoscaling Profile-4: Fixed Date Profile
- File: c7-07-web-linux-vmss-autoscaling-default-recurrence-fixed-profiles.tf
```t
## Major Changes in this Block
# 1. Capacity Block Values Change  (Minimum = 5, default = 5, Maximum = 20)
# 2. Fixed  Block for a specific day
# Profile-4: Fixed Profile for a Specific Day
  profile {
    name = "profile-4-fixed-profile"
  # Capacity Block     
    capacity {
      default = 5
      minimum = 5
      maximum = 20
    }
  # Fixed Block for a specific day
    fixed_date {
      timezone = "India Standard Time"
      start    = "2090-08-15T00:00:00Z"  # CHANGE TO THE DATE YOU ARE TESTING
      end      = "2090-08-15T23:59:59Z"  # CHANGE TO THE DATE YOU ARE TESTING
    }  
###########  START: Percentage CPU Metric Rules  ###########    
  ## Scale-Out 
    rule {
      .....
      REST ALL SAME DEFAULT Profile
      .....
      .....
}        
```


## Step-16: Apply and Verify VMSS Resource - Autoscaling Profile-4
```t
# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply 
terraform apply -auto-approve

# Verify VMSS Resource
1. Verify the VM Instances in VMSS Resources
2. 5 VM Instances should be created as per Capacity Block from Profile-4  
  # Capacity Block     
    capacity {
      default = 5
      minimum = 5
      maximum = 20
    }
3. Verify the Autoscaling Policy in Scaling Tab of VMSS Resource 
4. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -
  a. Profile-1: Default Profile
  b. Profile-2: Weekday Profile
  c. Profile-3: Weekend Profile
  d. Profile-4: Fixed Date Profile
```

## Step-17: Test Scale-Out and Scale-In scenarios
```t
# Connect to Bastion Host Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Host-LinuxVM-PublicIP>
sudo su - 

# Run the Load Test using Apache Bench
ab -k -t 1200 -n 9050000 -c 100 http://<Web-LB-Public-IP>/index.html
ab -k -t 1200 -n 9050000 -c 100 http://52.149.253.66/index.html

# Verify Scale-Out Event
1. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Instances
2. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Configure tab -> Open LB Connection Rule
3. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Run History Tab
4. Scale-Out Observation: A new VM should be created in VM Instances Tab of VMSS 

# Wait for 10 to 15 Minutes
- Wait for 10 to 15 minutes for "Scale-In" Event to Trigger

# Verify Scale-In Event
1. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Instances
2. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Configure tab -> Open LB Connection Rule
3. Go to -> Virtual Machine Scale Sets -> hr-dev-web-vmss -> Settings -> Scaling -> Run History Tab
4. Scale-In Observation: 1 VM should be deleted in VM Instances Tab of VMSS and should come down to value present in capacity block (capacity.minimum = 5 VMs)
```

## Step-18: Delete Resources
```t
# Delete Resources
terraform destroy 
[or]
terraform apply -destroy -auto-approve

# Important Notes
1. If any error occures during Destroy, again run same destroy command
2. If error continues during destroy consistently and no resources getting deleted, delete the Resource Group using Azure Portal Management Console.

# Error-1: Sample Error during Destroy
azurerm_subnet.appsubnet: Destruction complete after 21s
╷
│ Error: Error waiting for removal of Backend Address Pool Association for NIC "hr-dev-web-linuxvm-nic" (Resource Group "hr-dev-rg"): Code="OperationNotAllowed" Message="Operation 'startTenantUpdate' is not allowed on VM 'hr-dev-web-linuxvm' since the VM is marked for deletion. You can only retry the Delete operation (or wait for an ongoing one to complete)." Details=[]

# Clean-Up Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```

## Additional References

### Azure Autoscaling Open issues
- https://serverfault.com/questions/973421/terraform-autoscale-rule-to-scale-instance-to-specific-instance-count
- https://github.com/hashicorp/terraform-provider-azurerm/issues/3870

### Understanding Autoscaling in Azure
- https://docs.microsoft.com/en-us/azure/azure-monitor/autoscale/autoscale-understanding-settings