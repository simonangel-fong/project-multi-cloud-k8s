# outputs.tf

# ##############################
# Kubeconfig
# ##############################
output "kubeconfig_command" {
  description = "Run this to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ##############################
# Argocd
# ##############################
output "argocd_init_secret" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}

output "argocd_port_forward" {
  value = "kubectl -n argocd port-forward svc/argocd-server 8080:80"
}
