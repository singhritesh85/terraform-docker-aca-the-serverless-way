######################################## Create Azure VNet #####################################
resource "azurerm_virtual_network" "aca_vnet" {
  name                = "${var.prefix}-virtual-network"
  location            = azurerm_resource_group.aca_rg.location
  resource_group_name = azurerm_resource_group.aca_rg.name
  address_space       = ["10.10.0.0/16"]
  tags = {
    Environment = var.env
  }
}

######################################### Create Azure Subnet###################################
resource "azurerm_subnet" "azure_container_apps" {
  name                 = "containerapps-subnet"
  resource_group_name  = azurerm_resource_group.aca_rg.name
  virtual_network_name = azurerm_virtual_network.aca_vnet.name
  address_prefixes     = ["10.10.0.0/23"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]
}
