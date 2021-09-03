---
title: Azure Public DNS Zones using Terraform
description: Create Azure Public DNS Zones using Terraform
---
## Important Note: DNS Domain
- This demo requires registered DNS Domain, if you don't have one just please go through the demo to know more about Azure Public DNS Zones

## Step-00: Introduction
- Azure Public DNZ Zone Resources
1. azurerm_dns_zone
2. azurerm_dns_a_record - Root Record
3. azurerm_dns_a_record - www Record
4. azurerm_dns_a_record - app1 Record

## Step-01: c15-01-public-dns-zone-input-variables.tf
```t
# Input Variables Placeholder file
```

## Step-02: c15-02-public-dns-zone.tf
```t
# Datasource: Get DNS Record
data "azurerm_dns_zone" "dns_zone" {
  name                = "kubeoncloud.com"
  resource_group_name = "dns-zones"
}

# Resource-1: Add ROOT Record Set in DNS Zone
resource "azurerm_dns_a_record" "dns_record" {
  depends_on = [azurerm_lb.web_lb ]
  name                = "@"
  zone_name           = data.azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_dns_zone.dns_zone.resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.web_lbpublicip.id
}

# Resource-2: Add www Record Set in DNS Zone
resource "azurerm_dns_a_record" "dns_record_www" {
  depends_on = [azurerm_lb.web_lb ]  
  name                = "www"
  zone_name           = data.azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_dns_zone.dns_zone.resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.web_lbpublicip.id
}

# Resource-3: Add app1 Record Set in DNS Zone
resource "azurerm_dns_a_record" "dns_record_app1" {
  depends_on = [azurerm_lb.web_lb ]
  name                = "app1"
  zone_name           = data.azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_dns_zone.dns_zone.resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.web_lbpublicip.id
}
```

## Step-03: c15-03-public-dns-zone-output-values.tf
```t
# DNS Zone Datasource Outputs
output "dns_zone_id" {
  value = data.azurerm_dns_zone.dns_zone.id
}
output "dns_zone_name" {
  value = data.azurerm_dns_zone.dns_zone.name
}

# FQDN 
output "fqdn_public_dns_1" {
  description = "FQDN Public DNS 1"
  value = azurerm_dns_a_record.dns_record.fqdn
}

output "fqdn_public_dns_2" {
  description = "FQDN Public DNS 2"
  value = azurerm_dns_a_record.dns_record_www.fqdn
}

output "fqdn_public_dns_3" {
  description = "FQDN Public DNS 3"
  value = azurerm_dns_a_record.dns_record_app1.fqdn
}
```

## Step-04: Execute Terraform Commands
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

## Step-05: Verify Resources - Public DNS Records
```t
# Verify Public DNS Records
kubeoncloud.com
www.kubeoncloud.com
app1.kubeoncloud.com

# Wait for 10 to 15 mins to have entire provisioning completed
- All the resources will be provisioned from custom_data perspective in both Web and App Linux VMs

# Access App VM Pages (index.html page will be served from AppVM )
http://kubeoncloud.com
http://www.kubeoncloud.com
http://app1.kubeoncloud.com
http://kubeoncloud.com/appvm/index.html
http://www.kubeoncloud.com/appvm/index.html
http://app1.kubeoncloud.com/appvm/index.html


# Access Web VM Pages
http://kubeoncloud.com/webvm/index.html
http://www.kubeoncloud.com/webvm/index.html
http://app1.kubeoncloud.com/webvm/index.html
```

## Step-06: Delete Resources
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