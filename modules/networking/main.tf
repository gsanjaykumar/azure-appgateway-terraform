# ─── Virtual Network ──────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# ─── Subnets ──────────────────────────────────────────────────────────────────

# App Gateway subnet — no delegation
resource "azurerm_subnet" "appgateway" {
  name                 = var.appgateway_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.appgateway_subnet_cidr]

  # Private Link Service policies must be disabled on App GW subnet
  private_link_service_network_policies_enabled = false
}

# App Service integration subnet — delegated to Microsoft.Web/serverFarms
resource "azurerm_subnet" "appservice_integration" {
  name                 = var.appservice_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.appservice_subnet_cidr]

  delegation {
    name = "delegation-appservice"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Private endpoints subnet
resource "azurerm_subnet" "private_endpoints" {
  name                 = var.private_endpoint_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.private_endpoint_subnet_cidr]

  private_endpoint_network_policies_enabled = false
}

# ─── Network Security Group ───────────────────────────────────────────────────

resource "azurerm_network_security_group" "appgateway" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# ─── NSG Rules ────────────────────────────────────────────────────────────────

# CRITICAL: App Gateway v2 REQUIRES this rule for infrastructure communication
# Without this, App Gateway will fail to provision or become unhealthy
resource "azurerm_network_security_rule" "allow_gateway_manager" {
  name                        = "Allow-GatewayManager"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgateway.name
}

# Allow Front Door traffic (actual request forwarding)
resource "azurerm_network_security_rule" "allow_frontdoor_backend" {
  name                        = "Allow-FrontDoor-Backend"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgateway.name
}

# Allow Front Door health probes — DIFFERENT service tag from traffic!
# Lesson learned: missing this rule causes ConnectionFailure in FD health probe logs
resource "azurerm_network_security_rule" "allow_frontdoor_firstparty" {
  name                        = "Allow-FrontDoor-FirstParty"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "AzureFrontDoor.FirstParty"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgateway.name
}

# Allow Azure Load Balancer health checks
resource "azurerm_network_security_rule" "allow_azure_lb" {
  name                        = "Allow-AzureLoadBalancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgateway.name
}

# Optional: Allow direct internet access for testing
# Set enable_direct_access = true in tfvars for testing
# DISABLE in production — traffic should only come via Front Door
resource "azurerm_network_security_rule" "allow_direct_access" {
  count = var.enable_direct_access ? 1 : 0

  name                        = "Allow-Direct-HTTP-Test"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgateway.name
}

# Deny all other inbound traffic
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgateway.name
}

# ─── Associate NSG with App Gateway subnet ────────────────────────────────────

resource "azurerm_subnet_network_security_group_association" "appgateway" {
  subnet_id                 = azurerm_subnet.appgateway.id
  network_security_group_id = azurerm_network_security_group.appgateway.id
}
