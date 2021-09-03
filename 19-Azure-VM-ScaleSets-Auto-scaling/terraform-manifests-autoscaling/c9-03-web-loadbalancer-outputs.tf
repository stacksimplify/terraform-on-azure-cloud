# LB Public IP
output "web_lb_public_ip_address" {
  description = "Web Load Balancer Public Address"
  value = azurerm_public_ip.web_lbpublicip.ip_address
}

# Load Balancer ID
output "web_lb_id" {
  description = "Web Load Balancer ID."
  value = azurerm_lb.web_lb.id 
}

# Load Balancer Frontend IP Configuration Block
output "web_lb_frontend_ip_configuration" {
  description = "Web LB frontend_ip_configuration Block"
  value = [azurerm_lb.web_lb.frontend_ip_configuration]
}