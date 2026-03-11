variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "appgateway_subnet_name" {
  description = "Name of the App Gateway subnet"
  type        = string
}

variable "appgateway_subnet_cidr" {
  description = "CIDR block for App Gateway subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "appservice_subnet_name" {
  description = "Name of the App Service integration subnet"
  type        = string
}

variable "appservice_subnet_cidr" {
  description = "CIDR block for App Service integration subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_endpoint_subnet_name" {
  description = "Name of the private endpoints subnet"
  type        = string
}

variable "private_endpoint_subnet_cidr" {
  description = "CIDR block for private endpoints subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "nsg_name" {
  description = "Name of the Network Security Group"
  type        = string
}

variable "enable_direct_access" {
  description = "Allow direct internet access to App Gateway on port 80 (testing only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
