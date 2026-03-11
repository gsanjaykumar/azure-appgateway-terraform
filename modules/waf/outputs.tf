output "waf_policy_id" {
  description = "WAF policy resource ID"
  value       = azurerm_cdn_frontdoor_firewall_policy.waf.id
}

output "waf_policy_name" {
  description = "WAF policy name"
  value       = azurerm_cdn_frontdoor_firewall_policy.waf.name
}

output "waf_mode" {
  description = "Current WAF mode (Detection or Prevention)"
  value       = azurerm_cdn_frontdoor_firewall_policy.waf.mode
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.law.name
}

output "log_analytics_queries" {
  description = "Useful KQL queries for log analysis"
  value = {
    # Front Door logs
    fd_access_logs    = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.CDN' | where Category == 'FrontDoorAccessLog' | project TimeGenerated, requestUri_s, httpStatusCode_d, clientIp_s, userAgent_s | order by TimeGenerated desc | take 50"
    fd_waf_logs       = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.CDN' | where Category == 'FrontDoorWebApplicationFirewallLog' | project TimeGenerated, clientIP_s, requestUri_s, ruleName_s, action_s | order by TimeGenerated desc | take 50"
    fd_health_probes  = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.CDN' | where Category == 'FrontDoorHealthProbeLog' | project TimeGenerated, probeUrl_s, result_s, httpStatusCode_s | order by TimeGenerated desc | take 20"

    # App Gateway logs
    agw_access_logs   = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.NETWORK' | where Category == 'ApplicationGatewayAccessLog' | project TimeGenerated, requestUri_s, httpStatus_d, clientIP_s, userAgent_s, serverRouted_s | order by TimeGenerated desc | take 50"
    agw_health_probes = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.NETWORK' | where Category == 'ApplicationGatewayPerformanceLog' | project TimeGenerated, instanceId_s, healthyHostCount_d, requestCount_d | order by TimeGenerated desc | take 20"

    # Combined — full request journey (Front Door + App Gateway in one query)
    full_journey      = "AzureDiagnostics | where ResourceProvider in ('MICROSOFT.CDN', 'MICROSOFT.NETWORK') | where Category in ('FrontDoorAccessLog', 'ApplicationGatewayAccessLog') | project TimeGenerated, ResourceProvider, Category, requestUri_s, httpStatusCode_d, httpStatus_d, clientIp_s, clientIP_s | order by TimeGenerated desc | take 50"

    # WAF blocked requests
    waf_blocked       = "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.CDN' | where Category == 'FrontDoorWebApplicationFirewallLog' | where action_s == 'Block' | project TimeGenerated, clientIP_s, requestUri_s, ruleName_s, action_s | order by TimeGenerated desc"
  }
}
