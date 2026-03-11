# ─── DNS Records for Front Door Custom Domain ─────────────────────────────────
# TXT record  → proves domain ownership to Azure Front Door
# CNAME record → routes traffic from custom domain to Front Door endpoint

resource "azurerm_dns_txt_record" "validation" {
  count               = var.enable_custom_domain ? 1 : 0
  name                = "_dnsauth.${var.subdomain}"
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600

  record {
    value = var.custom_domain_validation_token
  }
}

resource "azurerm_dns_cname_record" "frontdoor" {
  count               = var.enable_custom_domain ? 1 : 0
  name                = var.subdomain
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record              = var.front_door_endpoint_hostname
}
