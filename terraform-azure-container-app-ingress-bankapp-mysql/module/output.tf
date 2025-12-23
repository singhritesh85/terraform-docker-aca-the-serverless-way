output "container_app_mysql_id" {
  description = "The ID of the MySQL Container App resource."
  value       = azurerm_container_app.aca_mysql_app.id
}

output "azurerm_container_app_mysql_url" {
  description = "The FQDN of the latest revision of the MySQL Container App (includes revision ID)"
  value = azurerm_container_app.aca_mysql_app.latest_revision_fqdn
}

output "container_app_bankapp_id" {
  description = "The ID of the BankApp Container App resource."
  value       = azurerm_container_app.aca_bankapp.id
}

output "azurerm_container_app_bankapp_url" {
  description = "The FQDN of the latest revision of the BankApp Container App (includes revision ID)"
  value = azurerm_container_app.aca_bankapp.latest_revision_fqdn
}

output "container_apps_environment_static_ip" {
  description = "The static IP address of the Container Apps Environment"
  value       = azurerm_container_app_environment.aca_environment.static_ip_address
}
