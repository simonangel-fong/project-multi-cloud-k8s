# outputs.tf

# # ##############################
# # kubeconfig
# # ##############################
# output "kubeconfig_command" {
#   description = "Run this to update your local kubeconfig"
#   value       = "az aks get-credentials --resource-group ${module.rg.rg_name} --name ${module.aks.cluster_name} --overwrite-existing"
# }
