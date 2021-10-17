output "vmss_public_ip_fqdn" {
  value = azurerm_public_ip.scale_set.fqdn
}

output "jumpbox_public_ip_fqdn" {
  value = azurerm_public_ip.scale_set.fqdn
}

output "jumpbox_public_ip" {
  value = azurerm_public_ip.scale_set.ip_address
}