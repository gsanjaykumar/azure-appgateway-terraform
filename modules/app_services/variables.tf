variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
}

variable "app_service_names" {
  description = "List of App Service names to create"
  type        = list(string)
}

variable "python_version" {
  description = "Python runtime version"
  type        = string
  default     = "3.12"
}

variable "appservice_subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
}

variable "appgateway_subnet_cidr" {
  description = "CIDR of App Gateway subnet for access restrictions"
  type        = string
}

variable "app_settings_base" {
  description = "Base application settings map"
  type        = map(string)
  default     = {}
}

variable "startup_command" {
  description = "Startup command for the web app"
  type        = string
  default     = "gunicorn --bind=0.0.0.0:8000 --timeout 120 app:app"
}

variable "app_zip_path" {
  description = "Path to the application ZIP file"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
