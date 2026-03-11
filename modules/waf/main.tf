# ─── Log Analytics Workspace ──────────────────────────────────────────────────

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# ─── Diagnostic Settings — Front Door ─────────────────────────────────────────
# LESSON LEARNED: Standard SKU logs to AzureDiagnostics (not AFDWebApplicationFirewallLog)
# Premium SKU logs to AFDWebApplicationFirewallLog
# Query: AzureDiagnostics | where ResourceProvider == "MICROSOFT.CDN"

resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = "${var.front_door_profile_name}-diag"
  target_resource_id         = var.front_door_profile_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ─── Diagnostic Settings — Application Gateway ────────────────────────────────
# Module 2 enhancement over Module 1 — captures App Gateway logs too
# Allows correlated queries showing full request journey:
#   Front Door access log → App Gateway access log → same request

resource "azurerm_monitor_diagnostic_setting" "appgateway" {
  name                       = "${var.app_gateway_name}-diag"
  target_resource_id         = var.app_gateway_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# ─── WAF Policy ───────────────────────────────────────────────────────────────
# LESSON LEARNED: WAF policy name must be alphanumeric only — NO hyphens!
# Hyphens cause silent failure: policy creates but events never log

resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                              = var.waf_policy_name
  resource_group_name               = var.resource_group_name
  sku_name                          = var.front_door_sku
  enabled                           = true
  mode                              = var.waf_mode
  redirect_url                      = var.waf_redirect_url
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("<html><body><h1>403 - Access Denied</h1><p>Your request has been blocked by the Web Application Firewall.</p></body></html>")
  tags                              = var.tags

  # Rule 1 — Rate Limiting
  custom_rule {
    name                           = "RateLimitRule"
    enabled                        = true
    priority                       = 1
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = var.waf_rate_limit_threshold
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "BeginsWith"
      negation_condition = false
      match_values       = ["/"]
    }
  }

  # Rule 2 — Block Bad Bots
  custom_rule {
    name     = "BlockBadBots"
    enabled  = true
    priority = 2
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestHeader"
      selector           = "User-Agent"
      operator           = "Contains"
      negation_condition = false
      match_values       = ["sqlmap", "nikto", "nmap", "masscan"]
      transforms         = ["Lowercase"]
    }
  }

  # Rule 3 — Geo Filtering
  custom_rule {
    name     = "GeoFilterRule"
    enabled  = true
    priority = 3
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = var.waf_allowed_countries
    }
  }
}

# ─── WAF Security Policy Association ─────────────────────────────────────────
# Links WAF policy to Front Door domains
# LESSON LEARNED: Security policy name must also be alphanumeric only!

resource "azurerm_cdn_frontdoor_security_policy" "waf_association" {
  name                     = "${var.waf_policy_name}secpolicy"
  cdn_frontdoor_profile_id = var.front_door_profile_id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id

      association {
        patterns_to_match = ["/*"]

        dynamic "domain" {
          for_each = var.front_door_domain_ids
          content {
            cdn_frontdoor_domain_id = domain.value
          }
        }
      }
    }
  }
}
