# variables.tf

variable "vpc_name" {
  description = "Name used to prefix all VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
