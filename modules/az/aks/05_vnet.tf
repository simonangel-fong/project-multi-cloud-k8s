# main.tf

# ##############################
# VNet
# ##############################
resource "azurerm_virtual_network" "this" {
  name                = local.common_name
  resource_group_name = var.rg_name
  location            = var.rg_location

  address_space = [var.vnet_cidr]

  tags = merge(
    var.tags,
    { Name = local.common_name }
  )
}

# ##############################
# AKS subnet
# ##############################
resource "azurerm_subnet" "this" {
  name                 = local.common_name
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [local.subnet_cidr]
}
