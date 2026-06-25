locals {

  # ##############################
  # Metadata
  # ##############################
  common_name = "${var.project_name}-${var.env}"

  # ##############################
  # Azure
  # ##############################
  default_tags = {
    Project     = var.project_name
    Environment = var.env
    ManagedBy   = "terraform"
  }

  # VNet
  vnet_cidr = "10.10.0.0/16"

  # AKS
  cluster_version = "1.36"
}
