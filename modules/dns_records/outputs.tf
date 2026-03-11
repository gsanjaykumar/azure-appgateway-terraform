output "txt_record_fqdn" {
  description = "FQDN of the TXT validation record"
  value       = var.enable_custom_domain ? azurerm_dns_txt_record.validation[0].fqdn : null
}

output "cname_record_fqdn" {
  description = "FQDN of the CNAME record"
  value       = var.enable_custom_domain ? azurerm_dns_cname_record.frontdoor[0].fqdn : null
}
