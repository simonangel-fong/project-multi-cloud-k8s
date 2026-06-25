# variables.tf

# ##############################
# Resource Group
# ##############################
variable "rg_name" {
  description = "Resource group hosting the VNet"
  type        = string
}

variable "rg_location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ##############################
# Networking
# ##############################
variable "vnet_cidr" {
  description = "CIDR block for the VNet"
  type        = string
  default     = "10.10.0.0/16"
}

# ##############################
# AKS
# ##############################
variable "cluster_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
}

# ##############################
# Default (system) node pool
# ##############################
variable "default_node_pool" {
  description = "Default system node pool settings"
  type = object({
    vm_size      = string
    node_count   = number
    min_count    = number
    max_count    = number
    auto_scaling = bool
  })
  default = {
    vm_size      = "standard_dc2s_v3"
    node_count   = 2
    min_count    = 1
    max_count    = 3
    auto_scaling = true
  }
}
