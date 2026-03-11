# ─── Azure DNS Zone ───────────────────────────────────────────────────────────
# This module ONLY creates the DNS Zone.
# It has NO dependency on Front Door — intentionally breaks the circular dependency:
#   dns_zone → front_door → dns_records
#
# IMPORTANT: Every time a DNS Zone is deleted and recreated, Azure assigns
# NEW nameservers. Always update your domain registrar (GoDaddy etc.)
# after recreating the DNS Zone!

resource "azurerm_dns_zone" "zone" {
  name                = var.domain_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
