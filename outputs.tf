output "public_ip_addresses" {
  value = azurerm_public_ip.main.*.ip_address
}

output "private_key" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}