# argocd.tf: eks

# ##############################
# ArgoCD: Cluster Secret
# ##############################
# EKS cluster
resource "kubernetes_secret" "eks_cluster" {
  provider = kubernetes.eks
  metadata {
    name      = "eks-incluster"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      cloud                            = "aws"
      workload                         = "demo-api"
    }
  }

  data = {
    name   = "eks-incluster"
    server = "https://kubernetes.default.svc"
    config = jsonencode({ tlsClientConfig = { insecure = false } })
  }
}

# ##############################
# Argo CD: Install
# ##############################
module "argocd" {
  source = "../../modules/aws/argocd"

  argocd_version = "9.7.0"

  depends_on = [module.eks_node_group_default]
}

# # ##############################
# # ArgoCD: App-of-apps
# # ##############################
# data "http" "argocd_root_app" {
#   url = "https://raw.githubusercontent.com/simonangel-fong/k8s-multi-cloud/refs/heads/master/argocd/00-root.yaml"
# }

# resource "kubernetes_manifest" "root" {
#   provider = kubernetes.eks
#   manifest = yamldecode(data.http.argocd_root_app.response_body)

#   depends_on = [module.argocd]
# }
