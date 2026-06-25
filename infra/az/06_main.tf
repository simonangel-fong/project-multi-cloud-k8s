# main.tf

# ##############################
# AKS
# ##############################
module "aks" {
  source = "../../modules/az/aks"

  # rg
  rg_name     = azurerm_resource_group.main.name
  rg_location = azurerm_resource_group.main.location
  tags        = local.default_tags

  # ####################
  # Networking
  # ####################
  vnet_cidr = local.vnet_cidr

  # ####################
  # AKS
  # ####################
  cluster_version = local.cluster_version
}
