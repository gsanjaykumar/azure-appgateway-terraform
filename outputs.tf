# ─── Resource Group ───────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

# ─── Networking ───────────────────────────────────────────────────────────────

output "vnet_name" {
  description = "Virtual Network name"
  value       = module.networking.vnet_name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.networking.vnet_id
}

# ─── App Services ─────────────────────────────────────────────────────────────

output "app_service_names" {
  description = "List of App Service names"
  value       = module.app_services.app_service_names
}

output "app_service_urls" {
  description = "Direct App Service URLs (should return 403 after lockdown)"
  value       = module.app_services.app_service_urls
}

output "app_service_hostnames" {
  description = "App Service hostnames used as App Gateway backend pool"
  value       = module.app_services.app_service_hostnames
}

# ─── Application Gateway ──────────────────────────────────────────────────────

output "app_gateway_name" {
  description = "Application Gateway name"
  value       = module.app_gateway.app_gateway_name
}

output "app_gateway_public_ip" {
  description = "Application Gateway public IP address"
  value       = module.app_gateway.app_gateway_public_ip
}

output "private_link_service_id" {
  description = "Private Link Service ID (null if Standard SKU)"
  value       = module.app_gateway.private_link_service_id
}

# ─── Front Door ───────────────────────────────────────────────────────────────

output "front_door_endpoint_url" {
  description = "Front Door default endpoint URL"
  value       = module.front_door.front_door_endpoint_url
}

output "front_door_endpoint_hostname" {
  description = "Front Door endpoint hostname"
  value       = module.front_door.front_door_endpoint_hostname
}

output "custom_domain_url" {
  description = "Custom domain URL (main entry point)"
  value       = module.front_door.custom_domain_url
}

output "custom_domain_validation_token" {
  description = "DNS TXT validation token for custom domain"
  value       = module.front_door.custom_domain_validation_token
  sensitive   = true
}

# ─── DNS ──────────────────────────────────────────────────────────────────────

output "dns_name_servers" {
  description = "Azure DNS nameservers — update these in GoDaddy after every recreate!"
  value       = module.dns_zone.dns_zone_name_servers
}

# ─── WAF ──────────────────────────────────────────────────────────────────────

output "waf_policy_name" {
  description = "WAF policy name"
  value       = var.enable_waf ? module.waf[0].waf_policy_name : "WAF disabled"
}

output "waf_mode" {
  description = "Current WAF mode"
  value       = var.enable_waf ? module.waf[0].waf_mode : "WAF disabled"
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = var.enable_waf ? module.waf[0].log_analytics_workspace_name : "WAF disabled"
}

output "kql_queries" {
  description = "KQL queries for log analysis"
  value       = var.enable_waf ? module.waf[0].log_analytics_queries : null
}

# ─── Deployment Summary ───────────────────────────────────────────────────────

output "deployment_summary" {
  description = "Complete deployment summary"
  value       = <<-EOT

  ╔══════════════════════════════════════════════════════════════╗
  ║        MODULE 2: Front Door + App Gateway + App Services     ║
  ╠══════════════════════════════════════════════════════════════╣
  ║  Architecture:                                               ║
  ║  Internet → Front Door (WAF) → App Gateway → App Services   ║
  ╠══════════════════════════════════════════════════════════════╣
  ║  ENTRY POINTS                                                ║
  ║  Custom Domain:   ${module.front_door.custom_domain_url}
  ║  Front Door URL:  ${module.front_door.front_door_endpoint_url}
  ║  App Gateway IP:  http://${module.app_gateway.app_gateway_public_ip}
  ╠══════════════════════════════════════════════════════════════╣
  ║  SECURITY VERIFICATION                                       ║
  ║  Direct App Svc access should return 403 Forbidden           ║
  ╠══════════════════════════════════════════════════════════════╣
  ║  TEST COMMANDS                                               ║
  ║  Health:   curl ${module.front_door.front_door_endpoint_url}/health
  ║  Network:  curl ${module.front_door.front_door_endpoint_url}/network
  ╠══════════════════════════════════════════════════════════════╣
  ║  DNS NAMESERVERS (update in GoDaddy after each recreate!)    ║
  ║  ${join("\n  ║  ", module.dns_zone.dns_zone_name_servers)}
  ╚══════════════════════════════════════════════════════════════╝

  EOT
}

# ─── Test Commands ────────────────────────────────────────────────────────────

output "test_commands" {
  description = "PowerShell commands to verify the deployment"
  value       = <<-EOT

  # 1. Test via Front Door endpoint
  Invoke-WebRequest -Uri "${module.front_door.front_door_endpoint_url}/health" -UseBasicParsing

  # 2. Test custom domain
  Invoke-WebRequest -Uri "${module.front_door.custom_domain_url}/health" -UseBasicParsing

  # 3. Verify network path (shows all hops)
  Invoke-WebRequest -Uri "${module.front_door.front_door_endpoint_url}/network" -UseBasicParsing

  # 4. Test direct App Service access (should return 403)
  Invoke-WebRequest -Uri "${module.app_services.app_service_urls[0]}" -UseBasicParsing

  # 5. Test direct App Gateway access
  Invoke-WebRequest -Uri "http://${module.app_gateway.app_gateway_public_ip}/health" -UseBasicParsing

  # 6. Verify DNS
  nslookup -type=CNAME ${var.subdomain}.${var.domain_name}
  nslookup -type=TXT _dnsauth.${var.subdomain}.${var.domain_name}

  EOT
}
