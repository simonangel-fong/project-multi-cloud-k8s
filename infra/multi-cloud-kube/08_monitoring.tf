# ##############################
# Monitoring: Grafana Cloud Secret (EKS)
# ##############################
resource "kubernetes_namespace" "monitoring_eks" {
  provider = kubernetes.eks
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks_node_group_default]
}

resource "kubernetes_secret" "grafana_cloud_eks" {
  provider = kubernetes.eks
  metadata {
    name      = "grafana-cloud"
    namespace = kubernetes_namespace.monitoring_eks.metadata[0].name
  }

  type = "Opaque"

  # Key naming:
  # - UPPER_CASE keys: consumed as env vars by Alloy (envFrom in ApplicationSet) and read via sys.env("...") in urlFrom.
  # - lower_case keys: consumed by the chart's auth.usernameKey / auth.passwordKey lookups.
  # Same value lives under both spellings so a single Secret feeds both code paths.
  data = {
    PROM_URL       = var.gc_prom_url
    LOGS_URL       = var.gc_logs_url
    FLEET_URL      = var.gc_fleet_url
    prom_username  = var.gc_prom_username
    prom_password  = var.gc_token
    logs_username  = var.gc_logs_username
    logs_password  = var.gc_token
    fleet_username = var.gc_fleet_username
    fleet_password = var.gc_token
  }
}

# ##############################
# Monitoring: Grafana Cloud Secret (AKS) — enable when AKS module is uncommented
# ##############################
# resource "kubernetes_namespace" "monitoring_aks" {
#   provider = kubernetes.aks
#   metadata {
#     name = "monitoring"
#   }
# }
#
# resource "kubernetes_secret" "grafana_cloud_aks" {
#   provider = kubernetes.aks
#   metadata {
#     name      = "grafana-cloud"
#     namespace = kubernetes_namespace.monitoring_aks.metadata[0].name
#   }
#
#   type = "Opaque"
#
#   data = {
#     PROM_URL       = var.gc_prom_url
#     LOGS_URL       = var.gc_logs_url
#     FLEET_URL      = var.gc_fleet_url
#     prom_username  = var.gc_prom_username
#     prom_password  = var.gc_token
#     logs_username  = var.gc_logs_username
#     logs_password  = var.gc_token
#     fleet_username = var.gc_fleet_username
#     fleet_password = var.gc_token
#   }
# }
