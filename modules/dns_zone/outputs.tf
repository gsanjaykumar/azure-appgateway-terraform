output "dns_zone_id" {
  description = "DNS Zone resource ID - passed to Front Door for custom domain association"
  value       = azurerm_dns_zone.zone.id
}

output "dns_zone_name" {
  description = "DNS Zone name"
  value       = azurerm_dns_zone.zone.name
}

output "dns_zone_name_servers" {
  description = "Name servers — update these in GoDaddy / your domain registrar after every recreate!"
  value       = azurerm_dns_zone.zone.name_servers
}
