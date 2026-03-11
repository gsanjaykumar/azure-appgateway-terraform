output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "appgateway_subnet_id" {
  description = "ID of the App Gateway subnet"
  value       = azurerm_subnet.appgateway.id
}

output "appgateway_subnet_cidr" {
  description = "CIDR of the App Gateway subnet"
  value       = var.appgateway_subnet_cidr
}

output "appservice_subnet_id" {
  description = "ID of the App Service integration subnet"
  value       = azurerm_subnet.appservice_integration.id
}

output "private_endpoint_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "nsg_id" {
  description = "ID of the Network Security Group"
  value       = azurerm_network_security_group.appgateway.id
}

output "nsg_name" {
  description = "Name of the Network Security Group"
  value       = azurerm_network_security_group.appgateway.name
}
