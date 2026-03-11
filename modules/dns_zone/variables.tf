variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g. contoso.com)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
