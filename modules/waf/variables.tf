variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "log_analytics_workspace_name" {
  description = "Name for the Log Analytics Workspace"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "front_door_profile_id" {
  description = "Front Door profile resource ID"
  type        = string
}

variable "front_door_profile_name" {
  description = "Front Door profile name"
  type        = string
}

variable "front_door_sku" {
  description = "Front Door SKU — must match WAF policy SKU"
  type        = string
}

variable "front_door_domain_ids" {
  description = "List of Front Door domain IDs to associate WAF policy with"
  type        = list(string)
}

variable "app_gateway_id" {
  description = "Application Gateway resource ID for diagnostic settings"
  type        = string
}

variable "app_gateway_name" {
  description = "Application Gateway name for diagnostic settings naming"
  type        = string
}

variable "waf_policy_name" {
  description = "WAF policy name — alphanumeric only, NO hyphens!"
  type        = string
}

variable "waf_mode" {
  description = "WAF mode: Detection or Prevention"
  type        = string
  default     = "Detection"
  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be Detection or Prevention."
  }
}

variable "waf_redirect_url" {
  description = "URL to redirect blocked requests (optional)"
  type        = string
  default     = null
}

variable "waf_rate_limit_threshold" {
  description = "Max requests per minute per IP"
  type        = number
  default     = 100
}

variable "waf_allowed_countries" {
  description = "List of allowed country codes for geo filtering"
  type        = list(string)
  default     = ["IN"]
}
