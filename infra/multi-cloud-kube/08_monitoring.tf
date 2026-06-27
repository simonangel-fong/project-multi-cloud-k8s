# monitoring.tf

# ##############################
# Monitoring: EKS
# ##############################
# namespace
resource "kubernetes_namespace" "monitoring_eks" {
  provider = kubernetes.eks
  metadata {
    name = "monitoring"
  }

  depends_on = [module.eks_node_group_default]
}

# Grafana Cloud Secret
resource "kubernetes_secret" "grafana_cloud_eks" {
  provider = kubernetes.eks
  metadata {
    name      = "grafana-cloud"
    namespace = kubernetes_namespace.monitoring_eks.metadata[0].name
  }

  type = "Opaque"
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
# Monitoring: AKS
# ##############################
# namespace
resource "kubernetes_namespace" "monitoring_aks" {
  provider = kubernetes.aks
  metadata {
    name = "monitoring"
  }

  depends_on = [module.aks]
}

# Grafana Cloud Secret
resource "kubernetes_secret" "grafana_cloud_aks" {
  provider = kubernetes.aks
  metadata {
    name      = "grafana-cloud"
    namespace = kubernetes_namespace.monitoring_aks.metadata[0].name
  }

  type = "Opaque"
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
