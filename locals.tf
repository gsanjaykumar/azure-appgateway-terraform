# ─── Random suffix for unique resource names ──────────────────────────────────

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ─── Naming conventions ───────────────────────────────────────────────────────

locals {
  suffix      = random_string.suffix.result
  name_prefix = "${var.project_name}-${var.environment}"

  # ── Resource names ──────────────────────────────────────────────────────────
  resource_group_name = var.resource_group_name

  # Networking
  vnet_name                    = "vnet-${local.name_prefix}"
  appgateway_subnet_name       = "snet-appgateway"
  appservice_subnet_name       = "snet-appservice-integration"
  private_endpoint_subnet_name = "snet-private-endpoints"
  nsg_name                     = "nsg-${local.name_prefix}"

  # App Services
  app_service_plan_name = "asp-${local.name_prefix}"
  app_service_names     = [for i in range(var.app_count) : "app-agw-${var.environment}-${i + 1}"]
  app_zip_path          = "${path.root}/app.zip"

  # Application Gateway
  app_gateway_name          = "agw-${local.name_prefix}"
  app_gateway_public_ip_name = "pip-${local.name_prefix}"
  private_link_service_name = "pls-${local.name_prefix}"

  # Front Door
  front_door_profile_name  = "afd-${local.name_prefix}"
  front_door_endpoint_name = "endpoint-${local.name_prefix}"
  front_door_origin_group  = "og-${local.name_prefix}"
  front_door_origin_name   = "origin-appgateway"

  # Custom domain resource name needs random suffix to avoid Azure API conflicts on re-deploy
  custom_domain_resource_name = "domain-${local.name_prefix}-${local.domain_suffix}"
  domain_suffix               = random_string.domain_suffix.result

  # DNS
  dns_zone_name = var.domain_name
  fqdn          = "${var.subdomain}.${var.domain_name}"

  # WAF — alphanumeric only! No hyphens (silent failure if hyphens used)
  waf_policy_name              = "${replace(local.name_prefix, "-", "")}waf${local.suffix}"
  log_analytics_workspace_name = "law-${local.name_prefix}-${local.suffix}"

  # ── Common tags ─────────────────────────────────────────────────────────────
  common_tags = merge(var.tags, {
    ManagedBy   = "Terraform"
    Environment = var.environment
    LastUpdated = timestamp()
  })
}
