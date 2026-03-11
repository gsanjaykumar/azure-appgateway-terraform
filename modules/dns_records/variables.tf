variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "dns_zone_name" {
  description = "Name of the existing DNS Zone"
  type        = string
}

variable "subdomain" {
  description = "Subdomain prefix (e.g. www)"
  type        = string
  default     = "www"
}

variable "front_door_endpoint_hostname" {
  description = "Front Door endpoint hostname"
  type        = string
}

variable "custom_domain_validation_token" {
  description = "Validation token from Front Door custom domain resource"
  type        = string
}

variable "enable_custom_domain" {
  description = "Whether to create the DNS records"
  type        = bool
  default     = true
}
