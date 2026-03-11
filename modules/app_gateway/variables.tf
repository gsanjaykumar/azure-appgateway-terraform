variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "public_ip_name" {
  description = "Name of the Public IP for App Gateway"
  type        = string
}

variable "app_gateway_sku" {
  description = "SKU tier for Application Gateway"
  type        = string
  default     = "Standard_v2"
}

variable "app_gateway_capacity" {
  description = "Number of Application Gateway instances"
  type        = number
  default     = 1
}

variable "appgateway_subnet_id" {
  description = "Subnet ID for Application Gateway deployment"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for Private Link Service NAT IPs"
  type        = string
}

variable "app_service_hostnames" {
  description = "List of App Service hostnames for backend pool"
  type        = list(string)
}

variable "probe_path" {
  description = "Health probe path"
  type        = string
  default     = "/health"
}

variable "probe_interval" {
  description = "Health probe interval in seconds"
  type        = number
  default     = 30
}

variable "probe_timeout" {
  description = "Health probe timeout in seconds"
  type        = number
  default     = 30
}

variable "probe_threshold" {
  description = "Unhealthy threshold for health probe"
  type        = number
  default     = 3
}

variable "private_link_service_name" {
  description = "Name of the Private Link Service"
  type        = string
}

variable "enable_private_link" {
  description = "Enable Private Link Service on App Gateway (required for Front Door Premium)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
