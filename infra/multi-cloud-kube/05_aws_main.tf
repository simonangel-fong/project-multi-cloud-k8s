# main.tf: aws

# ##############################
# VPC
# ##############################
module "vpc" {
  source = "../../modules/aws/vpc"

  vpc_name = local.common_name
  vpc_cidr = local.vpc_cidr
  vpc_tags = local.tags
}

# ##############################
# EKS
# ##############################
module "eks" {
  source = "../../modules/aws/eks"

  cluster_name    = local.common_name
  cluster_version = local.cluster_version
  subnet_ids      = module.vpc.private_subnet_ids
  cluster_tags    = local.tags
}

# ##############################
# EKS Node Group: default
# ##############################
module "eks_node_group_default" {
  source = "../../modules/aws/eks-node-group"

  cluster_name    = module.eks.cluster_name
  node_group_name = "default"
  subnet_ids      = module.vpc.private_subnet_ids

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  desired_size = 2
  min_size     = 2
  max_size     = 10

  tags = local.tags
}
