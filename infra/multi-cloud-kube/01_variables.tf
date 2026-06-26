# variables.tf

# ##############################
# Project Metadata
# ##############################
variable "project_name" {
  type    = string
  default = "multi-cloud-k8s"
}

# ##############################
# Environemnt
# ##############################
variable "env" {
  type = string
}

# ##############################
# AWS
# ##############################
variable "aws_region" {
  type = string
}

# ##############################
# Azure
# ##############################
variable "az_location" {
  type = string
}

# ##############################
# Grafana Cloud
# ##############################
variable "gc_prom_url" {
  type = string
}

variable "gc_prom_username" {
  type = string
}

variable "gc_logs_url" {
  type = string
}

variable "gc_logs_username" {
  type = string
}

variable "gc_fleet_url" {
  type = string
}

variable "gc_fleet_username" {
  type = string
}

variable "gc_token" {
  type      = string
  sensitive = true
}
