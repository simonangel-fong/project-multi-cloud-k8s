# locals.tf

locals {

  common_name = var.rg_name

  # /20 = 4,096 addresses for the AKS node/pod subnet
  subnet_cidr = cidrsubnet(var.vnet_cidr, 4, 0)
}
