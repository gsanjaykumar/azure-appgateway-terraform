output "app_gateway_id" {
  description = "Resource ID of the Application Gateway"
  value       = azurerm_application_gateway.appgateway.id
}

output "app_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.appgateway.name
}

output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgateway.ip_address
}

output "app_gateway_public_ip_id" {
  description = "Resource ID of the App Gateway Public IP"
  value       = azurerm_public_ip.appgateway.id
}

output "app_gateway_backend_pool_id" {
  description = "ID of the App Gateway backend address pool"
  value       = tolist(azurerm_application_gateway.appgateway.backend_address_pool)[0].id
}

output "private_link_service_id" {
  description = "Resource ID of the Private Link Service (if enabled)"
  value       = var.enable_private_link ? azurerm_private_link_service.appgateway[0].id : null
}

output "private_link_service_alias" {
  description = "Alias of the Private Link Service for Front Door Premium connection"
  value       = var.enable_private_link ? azurerm_private_link_service.appgateway[0].alias : null
}
