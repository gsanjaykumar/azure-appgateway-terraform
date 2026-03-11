variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region (needed for Private Link)"
  type        = string
}

variable "front_door_profile_name" {
  description = "Name of the Front Door profile"
  type        = string
}

variable "front_door_endpoint_name" {
  description = "Name of the Front Door endpoint"
  type        = string
}

variable "front_door_sku" {
  description = "SKU for Front Door (Standard_AzureFrontDoor or Premium_AzureFrontDoor)"
  type        = string
  default     = "Standard_AzureFrontDoor"
}

variable "origin_group_name" {
  description = "Name of the origin group"
  type        = string
}

variable "origin_name" {
  description = "Name of the origin"
  type        = string
  default     = "origin-appgateway"
}

variable "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  type        = string
}

variable "origin_priority" {
  description = "Origin priority (lower = higher priority)"
  type        = number
  default     = 1
}

variable "origin_weight" {
  description = "Origin weight for load balancing"
  type        = number
  default     = 1000
}

variable "health_probe_path" {
  description = "Health probe path"
  type        = string
  default     = "/health"
}

variable "health_probe_interval" {
  description = "Health probe interval in seconds"
  type        = number
  default     = 60
}

variable "health_probe_method" {
  description = "Health probe HTTP method"
  type        = string
  default     = "GET"
}

variable "sample_size" {
  description = "Load balancing sample size"
  type        = number
  default     = 4
}

variable "successful_samples" {
  description = "Required successful samples"
  type        = number
  default     = 3
}

variable "latency_sensitivity" {
  description = "Latency sensitivity in milliseconds"
  type        = number
  default     = 50
}

variable "enable_custom_domain" {
  description = "Enable custom domain"
  type        = bool
  default     = true
}

variable "custom_domain_fqdn" {
  description = "Fully qualified domain name for custom domain"
  type        = string
  default     = ""
}

variable "custom_domain_resource_name" {
  description = "Resource name for custom domain (with random suffix to avoid conflicts)"
  type        = string
  default     = ""
}

variable "dns_zone_id" {
  description = "DNS Zone resource ID"
  type        = string
  default     = ""
}

variable "private_link_service_id" {
  description = "Private Link Service ID (required for Front Door Premium)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
