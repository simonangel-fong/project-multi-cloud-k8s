# ##############################
# Resource Group
# ##############################
resource "azurerm_resource_group" "main" {
  name     = local.common_name
  location = var.az_location

  tags = local.default_tags
}
