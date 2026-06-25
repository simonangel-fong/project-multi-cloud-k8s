# main.tf

# ##############################
# Resource Group
# ##############################
resource "azurerm_resource_group" "main" {
  name     = local.common_name
  location = var.az_location
  tags     = local.tags
}

# ##############################
# AKS
# ##############################
module "aks" {
  source = "../modules/az/aks"

  # ####################
  # Resource Group
  # ####################
  rg_name     = azurerm_resource_group.main.name
  rg_location = azurerm_resource_group.main.location
  tags        = local.tags

  # ####################
  # Networking
  # ####################
  vnet_cidr = local.vnet_cidr

  # ####################
  # AKS
  # ####################
  cluster_version = local.cluster_version
}
