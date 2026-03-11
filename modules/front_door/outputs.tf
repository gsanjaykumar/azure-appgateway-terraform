output "front_door_id" {
  description = "Resource ID of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.profile.id
}

output "front_door_profile_name" {
  description = "Name of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.profile.name
}

output "front_door_endpoint_hostname" {
  description = "Default hostname of the Front Door endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.endpoint.host_name
}

output "front_door_endpoint_url" {
  description = "Default URL of the Front Door endpoint"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.endpoint.host_name}"
}

output "front_door_endpoint_id" {
  description = "Resource ID of the Front Door endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.endpoint.id
}

output "custom_domain_validation_token" {
  description = "DNS validation token for custom domain TXT record"
  value       = var.enable_custom_domain ? azurerm_cdn_frontdoor_custom_domain.domain[0].validation_token : null
}

output "custom_domain_url" {
  description = "Custom domain URL"
  value       = var.enable_custom_domain ? "https://${var.custom_domain_fqdn}" : null
}

output "front_door_custom_domain_id" {
  description = "Resource ID of the Front Door custom domain"
  value       = var.enable_custom_domain ? azurerm_cdn_frontdoor_custom_domain.domain[0].id : null
}

output "front_door_domain_ids" {
  description = "List of all domain IDs for WAF security policy association"
  value = var.enable_custom_domain ? [
    azurerm_cdn_frontdoor_endpoint.endpoint.id,
    azurerm_cdn_frontdoor_custom_domain.domain[0].id
  ] : [azurerm_cdn_frontdoor_endpoint.endpoint.id]
}
