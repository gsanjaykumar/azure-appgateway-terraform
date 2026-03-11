# ─── General ──────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "appgateway-demo"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "South India"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-appgateway-demo"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "AppGateway-Demo"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Module      = "2"
  }
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "appgateway_subnet_cidr" {
  description = "CIDR for Application Gateway subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "appservice_subnet_cidr" {
  description = "CIDR for App Service VNet integration subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_endpoint_subnet_cidr" {
  description = "CIDR for Private Endpoints subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "enable_direct_access" {
  description = "Allow direct internet access to App Gateway on port 80 (for testing only — disable in production)"
  type        = bool
  default     = false
}

# ─── App Service ──────────────────────────────────────────────────────────────

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
  validation {
    condition     = contains(["B1", "B2", "B3", "S1", "S2", "P1v2", "P2v2", "P3v2"], var.app_service_plan_sku)
    error_message = "Invalid App Service Plan SKU."
  }
}

variable "python_version" {
  description = "Python runtime version"
  type        = string
  default     = "3.12"
  validation {
    condition     = contains(["3.9", "3.10", "3.11", "3.12"], var.python_version)
    error_message = "Python version must be 3.9, 3.10, 3.11, or 3.12."
  }
}

variable "app_count" {
  description = "Number of App Service instances to create"
  type        = number
  default     = 2
  validation {
    condition     = var.app_count >= 1 && var.app_count <= 5
    error_message = "App count must be between 1 and 5."
  }
}

# ─── Application Gateway ──────────────────────────────────────────────────────

variable "app_gateway_sku" {
  description = "SKU tier for Application Gateway (Standard_v2 or WAF_v2)"
  type        = string
  default     = "Standard_v2"
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.app_gateway_sku)
    error_message = "App Gateway SKU must be Standard_v2 or WAF_v2."
  }
}

variable "app_gateway_capacity" {
  description = "Number of Application Gateway instances (1-10)"
  type        = number
  default     = 1
  validation {
    condition     = var.app_gateway_capacity >= 1 && var.app_gateway_capacity <= 10
    error_message = "App Gateway capacity must be between 1 and 10."
  }
}

variable "app_gateway_probe_path" {
  description = "Health probe path for Application Gateway"
  type        = string
  default     = "/health"
}

variable "app_gateway_probe_interval" {
  description = "Health probe interval in seconds"
  type        = number
  default     = 30
}

variable "app_gateway_probe_timeout" {
  description = "Health probe timeout in seconds"
  type        = number
  default     = 30
}

variable "app_gateway_probe_threshold" {
  description = "Number of failed probes before backend is marked unhealthy"
  type        = number
  default     = 3
}

# ─── Front Door ───────────────────────────────────────────────────────────────

variable "front_door_sku" {
  description = "SKU for Azure Front Door (Standard_AzureFrontDoor or Premium_AzureFrontDoor). Premium required for Private Link."
  type        = string
  default     = "Standard_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.front_door_sku)
    error_message = "Front Door SKU must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "health_probe_path" {
  description = "Health probe path for Front Door origin group"
  type        = string
  default     = "/health"
}

variable "health_probe_interval" {
  description = "Health probe interval in seconds for Front Door"
  type        = number
  default     = 60
}

variable "health_probe_method" {
  description = "Health probe HTTP method for Front Door (GET or HEAD)"
  type        = string
  default     = "GET"
}

# ─── Load Balancing ───────────────────────────────────────────────────────────

variable "origin_weight" {
  description = "Weight for load balancing (1-1000)"
  type        = number
  default     = 1000
}

variable "origin_priority" {
  description = "Priority for origin (lower = higher priority)"
  type        = number
  default     = 1
}

variable "sample_size" {
  description = "Number of samples for load balancing decisions"
  type        = number
  default     = 4
}

variable "successful_samples" {
  description = "Number of successful samples required"
  type        = number
  default     = 3
}

variable "latency_sensitivity" {
  description = "Latency sensitivity in milliseconds"
  type        = number
  default     = 50
}

# ─── Custom Domain & DNS ──────────────────────────────────────────────────────

variable "domain_name" {
  description = "Root domain name (e.g. example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain prefix (e.g. www)"
  type        = string
  default     = "www"
}

variable "enable_custom_domain" {
  description = "Enable custom domain and SSL certificate"
  type        = bool
  default     = true
}

variable "frontdoor_sp_app_id" {
  description = "Azure Front Door Service Principal App ID for DNS Zone Contributor role"
  type        = string
  default     = "ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037"
}

# ─── WAF ──────────────────────────────────────────────────────────────────────

variable "enable_waf" {
  description = "Enable WAF policy for Front Door"
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "WAF mode: Detection (log only) or Prevention (block)"
  type        = string
  default     = "Detection"
  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be Detection or Prevention."
  }
}

variable "waf_rate_limit_threshold" {
  description = "Maximum requests per minute per IP before rate limiting kicks in"
  type        = number
  default     = 100
}

variable "waf_allowed_countries" {
  description = "List of allowed country codes (ISO 3166-1 alpha-2). All others will be blocked."
  type        = list(string)
  default     = ["IN"]
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics Workspace"
  type        = number
  default     = 30
}
