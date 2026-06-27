# Documentation: Infrastructure with Terraform

[Back](../README.md)

- [Documentation: Infrastructure with Terraform](#documentation-infrastructure-with-terraform)
  - [Networking - Design](#networking---design)
    - [VPC](#vpc)
    - [VNet](#vnet)
  - [Development](#development)
    - [Terraform](#terraform)
    - [Connect Cluster](#connect-cluster)
    - [ArgoCD](#argocd)

---

## Networking - Design

### VPC

- `VPC` cidr range must be between
  - `/16` (65,536 IP addresses)
  - `/28` (16 IP addresses)
- VPC CIDR: `10.0.0.0/16`

| Subnet  | AZ            | CIDR          | Usable IPs |
| ------- | ------------- | ------------- | ---------- |
| public  | ca-central-1a | 10.0.0.0/24   | 251        |
| public  | ca-central-1b | 10.0.1.0/24   | 251        |
| public  | ca-central-1d | 10.0.2.0/24   | 251        |
| private | ca-central-1a | 10.0.64.0/18  | 16,379     |
| private | ca-central-1b | 10.0.128.0/18 | 16,379     |
| private | ca-central-1d | 10.0.192.0/18 | 16,379     |

---

### VNet

- `virtual networks` and `subnets` cidr range must be between
  - `/2` (4,194,304 IP addresses)
  - `/29` (8 IP addresses)

---

## Development

### Terraform

```sh
terraform -chdir=infra/multi-cloud-kube init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/multi-cloud-kube fmt && terraform -chdir=infra/multi-cloud-kube validate
terraform -chdir=infra/multi-cloud-kube plan
terraform -chdir=infra/multi-cloud-kube apply -auto-approve

terraform -chdir=infra/multi-cloud-kube destroy -auto-approve

terraform -chdir=infra/multi-cloud-kube output kubeconfig_eks
```

---

### Connect Cluster

```sh
# eks kubeconfig
aws eks update-kubeconfig --region ca-central-1 --name multi-cloud-k8s-dev

# aks kubeconfig
az aks get-credentials --resource-group multi-cloud-k8s-dev --name multi-cloud-k8s-dev --overwrite-existing

kubectl get nodes
```

---

### ArgoCD

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo
argocd login localhost:8080 --username admin --insecure

argocd cluster list

kubectl apply -f argocd/00-root.yaml
```
