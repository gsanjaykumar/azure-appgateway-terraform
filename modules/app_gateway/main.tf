# ─── Public IP for Application Gateway ───────────────────────────────────────
# MUST be Standard SKU + Static allocation for App Gateway v2
# Basic SKU or Dynamic allocation will cause provisioning failure

resource "azurerm_public_ip" "appgateway" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard" # MUST be Standard for App GW v2
  allocation_method   = "Static"   # MUST be Static for App GW v2
  tags                = var.tags
}

# ─── Application Gateway v2 ───────────────────────────────────────────────────

resource "azurerm_application_gateway" "appgateway" {
  name                = var.app_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # ── SKU ───────────────────────────────────────────────────────────────────
  sku {
    name     = var.app_gateway_sku
    tier     = var.app_gateway_sku
    capacity = var.app_gateway_capacity
  }

  # ── Gateway IP (which subnet to deploy into) ──────────────────────────────
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.appgateway_subnet_id
  }

  # ── Frontend ──────────────────────────────────────────────────────────────
  frontend_ip_configuration {
    name                 = "appgw-frontend-public"
    public_ip_address_id = azurerm_public_ip.appgateway.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  # ── Backend Pool ──────────────────────────────────────────────────────────
  # Uses App Service FQDNs (*.azurewebsites.net) as backend targets
  backend_address_pool {
    name  = "backendpool-appservices"
    fqdns = var.app_service_hostnames
  }

  # ── Backend HTTP Settings ─────────────────────────────────────────────────
  # HTTPS to App Services with Public CA validation
  # pick_host_name_from_backend_address = true is CRITICAL
  # Without this, App Gateway sends wrong Host header → App Service rejects with 404
  backend_http_settings {
    name                                = "httpsetting-appservices"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true # Sends correct *.azurewebsites.net hostname

    # No trusted_root_certificate needed — App Services use Public CA (DigiCert/Microsoft)
    # If using private/self-signed cert on backend, would need to upload .cer here
  }

  # ── Health Probe ──────────────────────────────────────────────────────────
  probe {
    name                                      = "probe-appservices"
    protocol                                  = "Https"
    path                                      = var.probe_path
    interval                                  = var.probe_interval
    timeout                                   = var.probe_timeout
    unhealthy_threshold                       = var.probe_threshold
    pick_host_name_from_backend_http_settings = true # Uses hostname from backend HTTP settings
    match {
      status_code = ["200-399"]
    }
  }

  # ── HTTP Listener ─────────────────────────────────────────────────────────
  # Listening on port 80 for incoming traffic from Front Door
  # Front Door → App Gateway communication is HTTP (port 80)
  http_listener {
    name                           = "listener-http"
    frontend_ip_configuration_name = "appgw-frontend-public"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  # ── Routing Rule ──────────────────────────────────────────────────────────
  request_routing_rule {
    name                       = "rule-http-to-backend"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "listener-http"
    backend_address_pool_name  = "backendpool-appservices"
    backend_http_settings_name = "httpsetting-appservices"
  }

  # ── SSL Policy ────────────────────────────────────────────────────────────
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  depends_on = [azurerm_public_ip.appgateway]
}

# ─── Private Link Service ─────────────────────────────────────────────────────
# Wraps the App Gateway frontend IP to enable Azure Front Door Premium
# to connect via private link instead of public internet
# NOTE: Front Door Standard SKU does NOT support Private Link
#       This resource is created for documentation/learning purposes
#       and will be used when front_door_sku = "Premium_AzureFrontDoor"

resource "azurerm_private_link_service" "appgateway" {
  count = var.enable_private_link ? 1 : 0

  name                = var.private_link_service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # NAT IP configuration — at least 1 required
  # Azure uses this to translate incoming PLS connections to App GW frontend IP
  nat_ip_configuration {
    name                       = "natip-pls-001"
    subnet_id                  = var.private_endpoint_subnet_id
    private_ip_address_version = "IPv4"
    primary                    = true
  }

  # Link to App Gateway frontend IP configuration
  load_balancer_frontend_ip_configuration_ids = [
    azurerm_application_gateway.appgateway.frontend_ip_configuration[0].id
  ]

  depends_on = [azurerm_application_gateway.appgateway]
}
