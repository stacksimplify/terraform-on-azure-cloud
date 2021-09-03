---
title: Azure Application Gateway SSL using Terraform
description: Create Azure Application Gateway SSL Self-Signed using Terraform
---
## Step-00: Introduction
0. Leverage `Section-27-Azure-Application-Gateway-Basics` and build on top of them all the below features
1. HTTP 80 Listener
2. HTTP 443 Listener
3. HTTP to HTTPS Redirect
4. Custom Error Pages for Application Gateway hosted on Azure Storage Account Static Website
5. Self Signed SSL Certificate - 20 years validity

## Step-01: Generate Self Signed SSL
```t
# Change to Directory
cd terraform-manifests/ssl-self-signed

# Generate Self Signed Certificate and Private Key
openssl req -newkey rsa:2048 -nodes -keyout httpd.key -x509 -days 7300 -out httpd.crt

# Sample Output
Kalyans-Mac-mini:ssl-self-signed kalyanreddy$ openssl req -newkey rsa:2048 -nodes -keyout httpd.key -x509 -days 7300 -out httpd.crt
Generating a 2048 bit RSA private key
...................+++
.....................................+++
writing new private key to 'httpd.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) []:IN
State or Province Name (full name) []:Telangana
Locality Name (eg, city) []:Hyderabad
Organization Name (eg, company) []:stacksimplify
Organizational Unit Name (eg, section) []:Cloud Courses
Common Name (eg, fully qualified host name) []:terraformguru.com
Email Address []:stacksimplify@gmail.com
Kalyans-Mac-mini:ssl-self-signed kalyanreddy$ 

# Verify files 
ls -lrta
```

## Step-02: Convert SSL Certificate, Key to PFX
```t
# Change to Directory
cd terraform-manifests/ssl-self-signed

# Generate PFX file
openssl pkcs12 -export -out httpd.pfx -inkey httpd.key -in httpd.crt -passout pass:kalyan

# Verify File
ls -lrta httpd.pfx
```

## Step-03: c10-01-storage-account-input-variables.tf
- Storage Account to host Azure Application Gateway Error Pages
```t
# Input variable definitions
variable "storage_account_name" {
  description = "The name of the storage account"
  type        = string
}
variable "storage_account_tier" {
  description = "Storage Account Tier"
  type        = string
}
variable "storage_account_replication_type" {
  description = "Storage Account Replication Type"
  type        = string
}
variable "storage_account_kind" {
  description = "Storage Account Kind"
  type        = string
}
variable "static_website_index_document" {
  description = "static website index document"
  type        = string
}
variable "static_website_error_404_document" {
  description = "static website error 404 document"
  type        = string
}
```

## Step-04: terraform.tfvars
```t
storage_account_name              = "staticwebsite"
storage_account_tier              = "Standard"
storage_account_replication_type  = "LRS"
storage_account_kind              = "StorageV2"
static_website_index_document     = "index.html"
static_website_error_404_document = "error.html"
```

## Step-05: c10-02-storage-account.tf
```t
# Resource-1: Create Azure Storage account
resource "azurerm_storage_account" "storage_account" {
  name                = "${var.storage_account_name}${random_string.myrandom.id}"
  resource_group_name = azurerm_resource_group.rg.name

  location                 = var.resource_group_location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind             = var.storage_account_kind

  static_website {
    index_document     = var.static_website_index_document
    error_404_document = var.static_website_error_404_document
  }
}

# Locals Block for Static html files for Azure Application Gateway 
locals {
  pages = ["index.html", "error.html", "502.html", "403.html"]
}

# Resource-2: Add Static html files to blob storage
resource "azurerm_storage_blob" "static_container_blob" {
  for_each = toset(local.pages)
  name                   = each.value
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source = "${path.module}/custom-error-pages/${each.value}"
}

```

## Step-06: c10-03-storage-account-outputs.tf
```t
# Storage Account Outputs
output "storage_account_primary_access_key" {
  value = azurerm_storage_account.storage_account.primary_access_key
  sensitive = true
}
output "storage_account_primary_web_endpoint" {
  value = azurerm_storage_account.storage_account.primary_web_endpoint
}
output "storage_account_primary_web_host" {
  value = azurerm_storage_account.storage_account.primary_web_host
}
output "storage_account_name" {
   value = azurerm_storage_account.storage_account.name 
}
```

## Step-07: c9-02-application-gateway-resource.tf - Locals Block
- Locals block for Azure Application Gateway re-arranged to support both HTTP and HTTPS Listeners and SSL Certificate
```t
# Azure Application Gateway - Locals Block 
#since these variables are re-used - a locals block makes this more maintainable
locals {
  # Generic 
  frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
  redirect_configuration_name    = "${azurerm_virtual_network.vnet.name}-rdrcfg"


  # App1
  backend_address_pool_name_app1      = "${azurerm_virtual_network.vnet.name}-beap-app1"
  http_setting_name_app1              = "${azurerm_virtual_network.vnet.name}-be-htst-app1"
  probe_name_app1                = "${azurerm_virtual_network.vnet.name}-be-probe-app1"

  # HTTP Listener -  Port 80
  listener_name_http                  = "${azurerm_virtual_network.vnet.name}-lstn-http"
  request_routing_rule_name_http      = "${azurerm_virtual_network.vnet.name}-rqrt-http"
  frontend_port_name_http             = "${azurerm_virtual_network.vnet.name}-feport-http"


  # HTTPS Listener -  Port 443
  listener_name_https                  = "${azurerm_virtual_network.vnet.name}-lstn-https"
  request_routing_rule_name_https      = "${azurerm_virtual_network.vnet.name}-rqrt-https"
  frontend_port_name_https             = "${azurerm_virtual_network.vnet.name}-feport-https"
  ssl_certificate_name                 = "my-cert-1" 
}
```

## Step-08: c9-02-application-gateway-resource.tf - Frontend Ports
```t
# Frontend Port  - HTTP Port 80
  frontend_port {
    name = local.frontend_port_name_http 
    port = 80    
  }

# Frontend Port  - HTTP Port 443
  frontend_port {
    name = local.frontend_port_name_https
    port = 443    
  }  
```

## Step-09: c9-02-application-gateway-resource.tf - HTTP to HTTPS Redirect
- Create HTTP Listener
- Create HTTP Routing Rule
- Create Redirect Config and associate to HTTP Routing Rule
```t

# HTTP Listener - Port 80
  http_listener {
    name                           = local.listener_name_http
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_http
    protocol                       = "Http"    
  }
# HTTP Routing Rule - HTTP to HTTPS Redirect
  request_routing_rule {
    name                       = local.request_routing_rule_name_http
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_http 
    redirect_configuration_name = local.redirect_configuration_name
  }
# Redirect Config for HTTP to HTTPS Redirect  
  redirect_configuration {
    name = local.redirect_configuration_name
    redirect_type = "Permanent"
    target_listener_name = local.listener_name_https
    include_path = true
    include_query_string = true
  }  
```

## Step-10: c9-02-application-gateway-resource.tf - SSL Certificate Block
```t
# SSL Certificate Block
  ssl_certificate {
    name = local.ssl_certificate_name
    password = "kalyan"
    data = filebase64("${path.module}/ssl-self-signed/httpd.pfx")
  }
```

## Step-11: c9-02-application-gateway-resource.tf - HTTPS Listener with Error Pages
```t

# HTTPS Listener - Port 443  
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"    
    ssl_certificate_name           = local.ssl_certificate_name    
    custom_error_configuration {
      custom_error_page_url = "${azurerm_storage_account.storage_account.primary_web_endpoint}502.html"
      status_code = "HttpStatus502"
    }
    custom_error_configuration {
      custom_error_page_url = "${azurerm_storage_account.storage_account.primary_web_endpoint}403.html"
      status_code = "HttpStatus403"
    }    
  }
```

## Step-12: c9-02-application-gateway-resource.tf - HTTPS Routing Rule
```t
# HTTPS Routing Rule - Port 443
  request_routing_rule {
    name                       = local.request_routing_rule_name_https
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_https
    backend_address_pool_name  = local.backend_address_pool_name_app1
    backend_http_settings_name = local.http_setting_name_app1    
  }
```

## Step-13: Execute Terraform Commands
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

## Step-14: Verify Resources
```t
# Azure Virtual Network Resources
1. Azure Virtual Network
2. Web, App, DB, Bastion and AG Subnets

# Azure Web VMSS
1. Azure VMSS
2. Azure VMSS Instances
3. Azure VMSS Autoscaling
4. Azure VMSS Topology

# Azure Application Gateway
1. AG Configuration Tab
2. AG Backend Pools
3. AG HTTP Settings
4. AG Frontend IP
5. AG SSL Settings (NONE)
6. AG Listeners
7. AG Rules
8. AG Health Probes
9. AG Insights
```
## Step-15: Add Host Entries and Test
- Test in Firefox browser which allows the SSL exception for Self-Signed Certificates
```t
# Add Host Entries
## Linux or MacOs
sudo vi /etc/hosts

### Host Entry Template
<AG-Public-IP>  terraformguru.com

### Host Entry Template - Replace AG-Public-IP
104.45.168.153  terraformguru.com

# Test HTTP to HTTPS Redirect
http://terraformguru.com/index.html
http://terraformguru.com/app1/index.html
http://terraformguru.com/app1/metadata.html
http://terraformguru.com/app1/status.html
http://terraformguru.com/app1/hostname.html
Observation: All these should auto-redirect from HTTP to HTTPS

# Test Error Pages
1. Stop VMSS Virtual Machine Instances
2. Wait for few minutes
http://terraformguru.com/index.html
http://terraformguru.com/app1/index.html
Observation: Static error pages hosted in Static Website should be displayed 

# Access Static Error Pgaes via Static Website Endpoint
http://<STATIC-WEBSITE-ENDPOINT>/502.html
http://<STATIC-WEBSITE-ENDPOINT>/403.html


# Remove / Comment Host Entries after testing 
## Linux or MacOs
sudo vi /etc/hosts
#20.81.19.52  app1.terraformguru.com
```


## Step-13: Destroy Resources
```t
# Destroy Resources
terraform destroy -auto-approve
or
terraform apply -destroy -auto-approve

# Delete Files
rm -rf .terraform* 
rm -rf terraform.tfstate*
```