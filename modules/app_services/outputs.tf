output "app_service_ids" {
  description = "List of App Service resource IDs"
  value       = azurerm_linux_web_app.apps[*].id
}

output "app_service_names" {
  description = "List of App Service names"
  value       = azurerm_linux_web_app.apps[*].name
}

output "app_service_hostnames" {
  description = "List of App Service default hostnames (used as App Gateway backend pool)"
  value       = azurerm_linux_web_app.apps[*].default_hostname
}

output "app_service_urls" {
  description = "List of App Service URLs with https://"
  value       = [for app in azurerm_linux_web_app.apps : "https://${app.default_hostname}"]
}

output "app_service_plan_id" {
  description = "App Service Plan resource ID"
  value       = azurerm_service_plan.plan.id
}

output "app_service_identities" {
  description = "Managed identity details for each App Service"
  value       = azurerm_linux_web_app.apps[*].identity
}
