# AKS: Terraform

Provision AKS on Azure, mirroring the `infra/aws` + `modules/aws` layout.

- **Root:** `infra/az/`
- **Modules:** `modules/az/aks/`
- **State:** S3, key `k8s-multi-cloud/az/terraform.tfstate`

## Layout

Each Terraform dir uses the same file split as `infra/aws`:

```
01_variables.tf
02_locals.tf
03_providers.tf
04_outputs.tf
05_main.tf
```

## Resources

| Resource | Key settings                                |
| -------- | ------------------------------------------- |
| RG       | name, location, tags                        |
| VNet     | CIDR sized for AKS pod/node scale; subnet   |
| AKS      | system-assigned identity; default node pool |

---

## Phases

| #   | Goal    | Done when                                                                 |
| --- | ------- | ------------------------------------------------------------------------- |
| 00  | Init    | Files scaffolded; backend configured; `terraform init` succeeds           |
| 01  | Network | RG + VNet + subnet applied; outputs exposed                               |
| 02  | AKS     | Cluster + default node pool Running; `az aks get-credentials` works       |
| 03  | Argo CD | Local Argo CD registers AKS; app-of-apps (`argocd/00-root.yaml`) deployed |

---

## Out of Scope (this stage)

- Private API server
- Multi-AZ / multi-region
- Workload identity, network policies, TLS

az aks nodepool scale \
 --resource-group multi-cloud-k8s-dev \
 --cluster-name multi-cloud-k8s-dev \
 --name system \
 --node-count 2

---

## Note

```sh
terraform -chdir=infra/az init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/az fmt && terraform -chdir=infra/az validate
terraform -chdir=infra/az plan
terraform -chdir=infra/az apply -auto-approve
terraform -chdir=infra/az output

terraform -chdir=infra/az destroy -auto-approve


az aks get-credentials --resource-group multi-cloud-k8s-dev --name multi-cloud-k8s-dev --overwrite-existing
kubectl get nodes
# NAME                             STATUS   ROLES    AGE     VERSION
# aks-system-22577710-vmss000000   Ready    <none>   8m46s   v1.36.0
# aks-system-22577710-vmss000001   Ready    <none>   8m43s   v1.36.0


argocd login localhost:8081 --username admin   --insecure
argocd cluster add multi-cloud-k8s-dev --name aks-dev --label cloud=azure --label workload=demo-api -y

argocd cluster list
# SERVER                                                                NAME           VERSION  STATUS      MESSAGE                                                  PROJECT
# https://kubernetes.default.svc                                        eks-incluster  v1.34.1  Successful
# https://multi-cloud-k8s-dev-3v6hymjq.hcp.canadacentral.azmk8s.io:443  aks-dev                 Unknown     Cluster has no applications and is not being monitored.

kubectl apply -f argocd/00-root.yaml
```
