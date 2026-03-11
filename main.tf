# ─────────────────────────────────────────────────────────────────────────────
# Module 2: Azure Front Door + Application Gateway + App Services
# Architecture: Internet → Front Door (WAF) → App Gateway → App Services (VNet)
#
# Deployment order:
#   Step 1: networking    → VNet, subnets, NSG
#   Step 2: dns_zone      → DNS Zone (no dependencies)
#   Step 3: app_services  → App Services + VNet integration + access restrictions
#   Step 4: app_gateway   → App GW v2 + Public IP + Private Link
#   Step 5: front_door    → FD profile + origin (App GW) + custom domain
#   Step 6: dns_records   → TXT + CNAME (depends on FD validation token)
#   Step 7: waf           → LAW + diagnostics (FD + AGW) + WAF policy
# ─────────────────────────────────────────────────────────────────────────────

# ─── Resource Group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ─── Step 1: Networking ───────────────────────────────────────────────────────

module "networking" {
  source = "./modules/networking"

  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  vnet_name                    = local.vnet_name
  vnet_address_space           = var.vnet_address_space
  appgateway_subnet_name       = local.appgateway_subnet_name
  appgateway_subnet_cidr       = var.appgateway_subnet_cidr
  appservice_subnet_name       = local.appservice_subnet_name
  appservice_subnet_cidr       = var.appservice_subnet_cidr
  private_endpoint_subnet_name = local.private_endpoint_subnet_name
  private_endpoint_subnet_cidr = var.private_endpoint_subnet_cidr
  nsg_name                     = local.nsg_name
  enable_direct_access         = var.enable_direct_access
  tags                         = local.common_tags

  depends_on = [azurerm_resource_group.rg]
}

# ─── Step 2: DNS Zone ─────────────────────────────────────────────────────────
# No dependency on Front Door — breaks circular dependency

module "dns_zone" {
  source = "./modules/dns_zone"

  resource_group_name = azurerm_resource_group.rg.name
  domain_name         = var.domain_name
  tags                = local.common_tags

  depends_on = [azurerm_resource_group.rg]
}

# ─── Step 3: App Services ─────────────────────────────────────────────────────
# Enhanced vs Module 1:
#   + VNet integration (outbound traffic through VNet)
#   + Access restrictions (only App GW subnet can reach App Services)

data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = "${path.root}/app"
  output_path = "${path.root}/app.zip"
}

module "app_services" {
  source = "./modules/app_services"

  resource_group_name    = azurerm_resource_group.rg.name
  location               = var.location
  app_service_plan_name  = local.app_service_plan_name
  app_service_plan_sku   = var.app_service_plan_sku
  app_service_names      = local.app_service_names
  python_version         = var.python_version
  appservice_subnet_id   = module.networking.appservice_subnet_id
  appgateway_subnet_cidr = var.appgateway_subnet_cidr
  app_zip_path           = data.archive_file.app_zip.output_path
  tags                   = local.common_tags

  depends_on = [module.networking, data.archive_file.app_zip]
}

# ─── Step 4: Application Gateway ─────────────────────────────────────────────
# Creates App GW v2 with backend pool pointing to App Services
# Also creates Private Link Service (enabled when front_door_sku = Premium)

module "app_gateway" {
  source = "./modules/app_gateway"

  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  app_gateway_name           = local.app_gateway_name
  public_ip_name             = local.app_gateway_public_ip_name
  app_gateway_sku            = var.app_gateway_sku
  app_gateway_capacity       = var.app_gateway_capacity
  appgateway_subnet_id       = module.networking.appgateway_subnet_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  app_service_hostnames      = module.app_services.app_service_hostnames
  probe_path                 = var.app_gateway_probe_path
  probe_interval             = var.app_gateway_probe_interval
  probe_timeout              = var.app_gateway_probe_timeout
  probe_threshold            = var.app_gateway_probe_threshold
  private_link_service_name  = local.private_link_service_name
  enable_private_link        = var.front_door_sku == "Premium_AzureFrontDoor" ? true : false
  tags                       = local.common_tags

  depends_on = [module.networking, module.app_services]
}

# ─── Step 5: Front Door ───────────────────────────────────────────────────────
# Origin points to App Gateway public IP (Standard SKU)
# or via Private Link Service (Premium SKU)
# Key difference from Module 1: origin is App Gateway, not App Service directly

# SP role assignment for DNS Zone (needed for Terraform to create DNS records)
data "azuread_service_principal" "frontdoor" {
  count     = var.enable_custom_domain ? 1 : 0
  client_id = var.frontdoor_sp_app_id
}

resource "azurerm_role_assignment" "frontdoor_dns" {
  count                = var.enable_custom_domain ? 1 : 0
  scope                = module.dns_zone.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = data.azuread_service_principal.frontdoor[0].object_id

  depends_on = [module.dns_zone]
}

module "front_door" {
  source = "./modules/front_door"

  resource_group_name         = azurerm_resource_group.rg.name
  location                    = var.location
  front_door_profile_name     = local.front_door_profile_name
  front_door_endpoint_name    = local.front_door_endpoint_name
  front_door_sku              = var.front_door_sku
  origin_group_name           = local.front_door_origin_group
  origin_name                 = local.front_door_origin_name
  app_gateway_public_ip       = module.app_gateway.app_gateway_public_ip
  origin_priority             = var.origin_priority
  origin_weight               = var.origin_weight
  health_probe_path           = var.health_probe_path
  health_probe_interval       = var.health_probe_interval
  health_probe_method         = var.health_probe_method
  sample_size                 = var.sample_size
  successful_samples          = var.successful_samples
  latency_sensitivity         = var.latency_sensitivity
  enable_custom_domain        = var.enable_custom_domain
  custom_domain_fqdn          = "${var.subdomain}.${var.domain_name}"
  custom_domain_resource_name = local.custom_domain_resource_name
  dns_zone_id                 = module.dns_zone.dns_zone_id
  private_link_service_id     = module.app_gateway.private_link_service_id
  tags                        = local.common_tags

  depends_on = [module.app_gateway, module.dns_zone, azurerm_role_assignment.frontdoor_dns]
}

# ─── Step 6: DNS Records ──────────────────────────────────────────────────────
# Created AFTER Front Door so we have the validation token
# TXT record proves domain ownership
# CNAME record routes traffic to Front Door endpoint

module "dns_records" {
  source = "./modules/dns_records"

  resource_group_name            = azurerm_resource_group.rg.name
  dns_zone_name                  = module.dns_zone.dns_zone_name
  subdomain                      = var.subdomain
  front_door_endpoint_hostname   = module.front_door.front_door_endpoint_hostname
  custom_domain_validation_token = module.front_door.custom_domain_validation_token
  enable_custom_domain           = var.enable_custom_domain

  depends_on = [module.front_door]
}

# ─── Step 7: WAF + Monitoring ─────────────────────────────────────────────────
# Enhanced vs Module 1:
#   + App Gateway diagnostic settings (new!)
#   + Combined KQL queries across FD + AGW

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "./modules/waf"

  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  log_analytics_workspace_name = local.log_analytics_workspace_name
  log_retention_days           = var.log_retention_days
  front_door_profile_id        = module.front_door.front_door_id
  front_door_profile_name      = module.front_door.front_door_profile_name
  front_door_sku               = var.front_door_sku
  front_door_domain_ids        = module.front_door.front_door_domain_ids
  app_gateway_id               = module.app_gateway.app_gateway_id
  app_gateway_name             = module.app_gateway.app_gateway_name
  waf_policy_name              = local.waf_policy_name
  waf_mode                     = var.waf_mode
  waf_rate_limit_threshold     = var.waf_rate_limit_threshold
  waf_allowed_countries        = var.waf_allowed_countries
  tags                         = local.common_tags

  depends_on = [module.front_door, module.app_gateway]
}
