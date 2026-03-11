# ─── Front Door Profile ───────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_profile" "profile" {
  name                = var.front_door_profile_name
  resource_group_name = var.resource_group_name
  sku_name            = var.front_door_sku
  tags                = var.tags
}

# ─── Endpoint ─────────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = var.front_door_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id
  tags                     = var.tags
}

# ─── Origin Group ─────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_origin_group" "origin_group" {
  name                     = var.origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id

  load_balancing {
    sample_size                 = var.sample_size
    successful_samples_required = var.successful_samples
    additional_latency_in_milliseconds = var.latency_sensitivity
  }

  health_probe {
    protocol            = "Http"   # MUST match App Gateway listener protocol
    path                = var.health_probe_path
    request_type        = var.health_probe_method
    interval_in_seconds = var.health_probe_interval
  }
}

# ─── Origin ───────────────────────────────────────────────────────────────────
# Points to App Gateway Public IP (not App Service directly — key difference from Module 1)
# Front Door Standard: public HTTP/HTTPS connection to App Gateway
# Front Door Premium:  Private Link connection (requires enable_private_link = true)

resource "azurerm_cdn_frontdoor_origin" "appgateway" {
  name                          = var.origin_name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group.id

  host_name          = var.app_gateway_public_ip
  http_port          = 80
  https_port         = 443
  origin_host_header = var.app_gateway_public_ip # Override host header sent to App GW
  priority           = var.origin_priority
  weight             = var.origin_weight

  # App Gateway uses public cert — certificate check enabled
  certificate_name_check_enabled = true

  # Private Link — only available with Front Door Premium SKU
  dynamic "private_link" {
    for_each = var.front_door_sku == "Premium_AzureFrontDoor" && var.private_link_service_id != null ? [1] : []
    content {
      request_message        = "FrontDoor Private Link Connection"
      location               = var.location
      private_link_target_id = var.private_link_service_id
    }
  }
}

# ─── Custom Domain ────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_custom_domain" "domain" {
  count = var.enable_custom_domain ? 1 : 0

  # Random suffix prevents "AfdDomainName already exists" error on re-deploy
  name                     = var.custom_domain_resource_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id
  dns_zone_id              = var.dns_zone_id
  host_name                = var.custom_domain_fqdn

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

# ─── Security Headers Rule Set ────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_rule_set" "security_headers" {
  name                     = "SecurityHeaders"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id
}

resource "azurerm_cdn_frontdoor_rule" "security_headers" {
  name                      = "AddSecurityHeaders"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.security_headers.id
  order                     = 1
  behavior_on_match         = "Continue"

  actions {
    response_header_action {
      header_action = "Overwrite"
      header_name   = "Strict-Transport-Security"
      value         = "max-age=31536000; includeSubDomains"
    }
    response_header_action {
      header_action = "Overwrite"
      header_name   = "X-Content-Type-Options"
      value         = "nosniff"
    }
    response_header_action {
      header_action = "Overwrite"
      header_name   = "X-Frame-Options"
      value         = "SAMEORIGIN"
    }
    response_header_action {
      header_action = "Overwrite"
      header_name   = "X-XSS-Protection"
      value         = "1; mode=block"
    }
    response_header_action {
      header_action = "Overwrite"
      header_name   = "X-Network-Path"
      value         = "FrontDoor-AppGateway-AppService"
    }
  }
}

# ─── Route ────────────────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_route" "route" {
  name    = "route-appgateway"
  cdn_frontdoor_endpoint_id   = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.appgateway.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.security_headers.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpOnly" # Forward HTTP to App Gateway (port 80 listener)
  https_redirect_enabled = true
  link_to_default_domain = true

  cdn_frontdoor_custom_domain_ids = var.enable_custom_domain ? [
    azurerm_cdn_frontdoor_custom_domain.domain[0].id
  ] : []

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = false
  }
}

# ─── Custom Domain Association ────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_custom_domain_association" "domain_association" {
  count = var.enable_custom_domain ? 1 : 0

  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.domain[0].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.route.id]
}
