---
title: Azure Standard Load Balancer using Terraform
description: Create Azure Standard Load Balancer using Terraform
---
## Step-00: Usecase Introduction
1. Create a Simple VNet with two Azure Linux VMs by provisioning sample webserver
2. Front these VMs with a Azure Standard Load Balancer
3. Over the proces learn the following load balancer concepts
- Frontend IPs
- Backend Pools
- Health Probes
- Load Balancing Rules
- Inbound NAT Rules
3. Verify the same via browser
4. Implement Inbount NAT rules via LB and connect to VMs using SSH

## Step-01: Create two Azure VMs in a Virtual Network
- Create Resource Group: slb-demo
- Create Virtual Network: vnet1
- VM Names: vm1, vm2
- Custom Data: app-scripts/redhat-webvm-script.sh

## Step-02: Create Azure Standard Load Balancer
1. Create Load Balancer with atleast one Frontend IP
2. Create Backend Pool in LB
3. Create Health Probe
4. Create Load Balancing Rule
5. Create Two Inbound NAT Rules

## Step-03: Test by accessing the Application
```t
# Curl Test 
curl http://<LB-Public-IP>

# Browser Test
http://<LB-Public-IP>
```

## Step-04: Inbout NAT Rules Test
```t
# SSH Test to VM1
ssh -i manual-lb.pem -p 1022 azureuser@<LB-Public-IP>

# SSH Test to VM2
ssh -i manual-lb.pem -p 2022 azureuser@<LB-Public-IP>
```

## Step-05: Outbound Rules
```t
# SSH Test to VM1
ssh -i manual-lb.pem -p 1022 azureuser@<LB-Public-IP>

# Apache Bench Testing
ab -t 240 -n 100000 -c 100 http://<LB-Public-IP>/index.html
ab -t 240 -n 100000 -c 100 http://40.121.55.137/index.html
-t Time it need to run
-n Number of Requests
-c concurrency
```