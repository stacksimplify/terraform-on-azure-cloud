---
title: Azure Private DNS Zones using Terraform
description: Create Azure Private DNS Zones using Terraform
---

## Step-00: Introduction
### Concepts
1. Create Azure Private DNS Zone `terraformguru.com`
2. Register the `Internal LB Static IP` to Private DNS name `applb.terraformguru.com`
3. Update the `app1.conf` which deploys on Web VMSS to Internal LB DNS Name instead of IP Address. 

### Azure Resources
1. azurerm_private_dns_zone
2. azurerm_private_dns_a_record

### New Files: Azure Private DNS Zone
1. c14-01-private-dns-zone-input-variables.tf
2. c14-02-private-dns-zone.tf
3. c14-03-private-dns-zone-outputs.tf

### Update to Files
1. app-scripts/app1.conf


## Step-01: c14-01-private-dns-zone-input-variables.tf
```t
# Input Variables Place holder file
```
## Step-02: c14-02-private-dns-zone.tf
```t
# Resource-1: Create Azure Private DNS Zone
resource "azurerm_private_dns_zone" "private_dns_zone" {
  name                = "terraformguru.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Resource-2: Associate Private DNS Zone to Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_zone_vnet_associate" {
  name                  = "${local.resource_name_prefix}-private-dns-zone-vnet-associate"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Resource-3: Internal Load Balancer
resource "azurerm_private_dns_a_record" "app_lb_dns_record" {
  depends_on = [azurerm_lb.app_lb]
  name                = "applb" 
  zone_name           = azurerm_private_dns_zone.private_dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = ["${azurerm_lb.app_lb.frontend_ip_configuration[0].private_ip_address}"]
}
```

## Step-03: c14-03-private-dns-zone-outputs.tf
```t
# FQDN Outputs
output "fqdn_app_lb" {
  description = "App LB FQDN"
  value = azurerm_private_dns_a_record.app_lb_dns_record.fqdn
}
```

## Step-04: app-scripts/app1.conf
```t
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
LoadModule proxy_http_module modules/mod_proxy_http.so

<VirtualHost *:80>
ServerName kubeoncloud.com
ProxyPreserveHost On
ProxyPass /webvm !

# Use when only IP Addresses are used - Section-15
#ProxyPass / http://10.1.11.241/
#ProxyPassReverse / http://10.1.11.241/

# Use the below when using Private DNS Section - Section-16
ProxyPass / http://applb.terraformguru.com/
ProxyPassReverse / http://applb.terraformguru.com/

DocumentRoot /var/www/html
<Directory /var/www/html>
Options -Indexes
Order allow,deny
Allow from all
</Directory>
</VirtualHost>

```

## Step-05: Execute Terraform Commands
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

## Step-06: Verify Private DNS using nslookup
```t
# Connect to Bastion Host
ssh -i ssh-keys/terraform-azure.pem azure@<Bastion-Public-IP>

# Perform nslookup Tests - Verify Private DNS
nslookup applb.terraformguru.com
```


## Step-07: Verify Resources Part-1
- **Important-Note:**  It will take 5 to 10 minutes to provision all the commands outlined in VM Custom Data
```t
# Verify Resources - Virtual Network
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnets (Web, App, DB, Bastion)
4. Azure Network Security Groups (Web, App, DB, Bastion)
5. View the topology
6. Verify Terraform Outputs in Terraform CLI

# Verify Resources - Web Linux VMSS 
1. Verify Web Linux VM Scale Sets
2. Verify Virtual Machines in VM Scale Sets
3. Verify Private IPs for Virtual Machines
4. Verify Autoscaling Policy

# Verify Resources - App Linux VMSS 
1. Verify App Linux VM Scale Sets
2. Verify Virtual Machines in VM Scale Sets
3. Verify Private IPs for Virtual Machines
4. Verify Autoscaling Policy


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


# 1. Connect to Web Linux VMs in Web VMSS using Bastion Host VM
1. Connect to Web Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PrivateIP-1>
ssh -i ssh-keys/terraform-azure.pem azureuser@<Web-LinuxVM-PrivateIP-2>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/webvm
ls -lrt
exit
exit

# 2. Connect to App Linux VMs in App VMSS using Bastion Host VM
1. Connect to App Linux VM
ssh -i ssh-keys/terraform-azure.pem azureuser@<App-LinuxVM-PrivateIP-1>
ssh -i ssh-keys/terraform-azure.pem azureuser@<App-LinuxVM-PrivateIP-2>
sudo su - 
cd /var/log
tail -100f cloud-init-output.log
cd /var/www/html
ls -lrt
cd /var/www/html/appvm
ls -lrt
exit
exit

# Web LB: Verify Internet Facing: Standard Load Balancer Resources 
1. Verify Public IP Address for Standard Load Balancer
2. Verify Standard Load Balancer (SLB) Resource
3. Verify SLB - Frontend IP Configuration
4. Verify SLB - Backend Pools
5. Verify SLB - Health Probes
6. Verify SLB - Load Balancing Rules
7. Verify SLB - Insights
8. Verify SLB - Diagnose and Solve Problems

# App LB: Verify Internal Loadbalancer: Standard Load Balancer Resources 
1. Verify Standard Load Balancer (SLB) Resource - Internal LB
2. Verify ISLB - Frontend IP Configuration (IP should be appsubnet IP)
3. Verify ISLB - Backend Pools
4. Verify ISLB - Health Probes
5. Verify ISLB - Load Balancing Rules
6. Verify ISLB - Insights
7. Verify ISLB - Diagnose and Solve Problems
```



## Step-08: Verify Resources Part-2
- **Important-Note:** It will take 5 to 10 minutes to provision all the commands outlined in VM Custom Data
```t
# Verify Storage Account
1. Verify Storage Account
2. Verify Storage Container
3. Verify app1.conf in Storage Container
4. We are also enabling this container with error pages in that as a static website. That we will use during the Azure Application Gateway usecases. 

# Verify NAT Gateway
1. Verify NAT Gateway 
2. Verify NAT Gateway -> Outbound IP
3. Verify NAT Gateway -> Subnets Associated

# Verify App Linux VM
1. Verify Network Interface created for App Linux VM
2. Verify App Linux VM
3. Verify Network Security Groups associated with VM (App Subnet NSG)
4. View Topology at App Linux VM -> Networking
5. Verify if only private IP associated with App Linux VM
6. Connect to Bastion Host and from there connect to App linux VM

# Connect to Bastion Host
ssh -i ssh-keys/terraform-azure.pem azureuser@<Bastion-Public-IP>
sudo su -
cd /tmp

# Connect to App Linux VM using Bastion Host and Verify Files
- Here App Linux VM will communicate to Internet via NAT Gateway (Outbound Communication) to download and install the "httpd" binary.
ssh -i terraform-azure.pem azureuser@<App-Linux-VM>
sudo su -
cd /var/log
tail -100f /var/log/cloud-init-output.log
cd /var/www/html
ls
cd appvm
ls

# Perform Curl Test on App VM
curl http://<APP-VM-private-IP>
curl http://10.1.11.4

# Sample Output
[root@hr-dev-app-linuxvm ~]# curl http://10.1.11.4
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-app-linuxvm ~]# 

# Exit from App VM
exit
exit

# Verify App LB
1. Verify Standard Load Balancer (SLB) Resource - App LB
3. Verify App SLB - Frontend IP Configuration
4. Verify App SLB - Backend Pools
5. Verify App SLB - Health Probes
6. Verify App SLB - Load Balancing Rules
7. Verify App SLB - Insights
8. Verify App SLB - Diagnose and Solve Problems

# From Bastion Host - perform Curl Test to Azure Internal Standard Load Balancer
curl http://<APP-Loadbalancer-DNS>
curl http://applb.terraformguru.com

## Sample Ouptut
[root@hr-dev-bastion-linuxvm tmp]# curl http://10.1.11.241
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-bastion-linuxvm tmp]# 


# Verify Web Linux VM
ssh -i terraform-azure.pem azureuser@<Web-Linux-VM>
sudo su -
cd /var/log
tail -100f /var/log/cloud-init-output.log # It took 600 seconds for full custom data provisioning
cd /var/www/html
ls
cd webvm
ls
cd /etc/httpd/conf.d
ls  # Verify app1.conf downloaded

# Sample Output at the end of 
  "snapshot": null
}
Cloud-init v. 19.4 running 'modules:final' at Thu, 05 Aug 2021 11:44:05 +0000. Up 32.90 seconds.
Cloud-init v. 19.4 finished at Thu, 05 Aug 2021 11:53:39 +0000. Datasource DataSourceAzure [seed=/dev/sr0].  Up 607.09 seconds
^C
[root@hr-dev-web-linuxvm log]# 

# From Web VM Host - perform Curl Test to Azure Internal Standard Load Balancer
curl http://<APP-Loadbalancer-IP>
curl http://10.1.11.241

# Sample Output
[root@hr-dev-web-linuxvm conf.d]# curl http://10.1.11.241
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-web-linuxvm conf.d]# 

# From Web VM Host - perform Curl Test using Web VM Private IP
curl http://<Web-VM-Private-IP>
curl http://10.1.1.4

# Sample Output
[root@hr-dev-web-linuxvm conf.d]# curl http://10.1.1.4
Welcome to stacksimplify - AppVM App1 - VM Hostname: hr-dev-app-linuxvm
[root@hr-dev-web-linuxvm conf.d]# 

# Access Application using Internet facing Azure Standard Load Balancer Public
## Web VM Files
http://<LB-Public-IP>/webvm/index.html # Should be served from web Linux VM
http://<LB-Public-IP>/webvm/metadata.html

## App VM Files
http://<LB-Public-IP>/ # index.html should be served from App Linux VM
http://<LB-Public-IP>/appvm/index.html # Should be served from app Linux VM
http://<LB-Public-IP>/appvm/metadata.html
```


## Step-09: Delete Resources
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

## Additional References - Reverse Proxy Outbound open on RedHat VM Apache2
```t
# Reference Link
https://confluence.atlassian.com/bitbucketserverkb/permission-denied-in-apache-logs-when-used-as-a-reverse-proxy-790957647.html
# Command
/usr/sbin/setsebool -P httpd_can_network_connect 1
```

