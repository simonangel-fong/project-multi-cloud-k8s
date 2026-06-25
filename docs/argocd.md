# Argo CD: GitOps for k8s-multi-cloud

Install Argo CD and use the app-of-apps pattern to deploy Envoy Gateway and `demo-api` declaratively.

## Installation

| Env | Method                     |
| --- | -------------------------- |
| aws | EKS, install via Terraform |

## Repo Layout

```
argocd/
  00-root.yaml          # root Application — points at app/
  app/
    00-clusters.yaml
    01-envoy-gateway.yaml
    02-envoy-gateway-config.yaml
    03-demo-api.yaml    # ApplicationSet (clusters generator)
  clusters/
    eks-incluster.yaml  # cluster Secret with labels cloud=aws, workload=demo-api
  envoy-gateway-config/
    gatewayclass.yaml
    gateway.yaml
```

## Goals

- Bootstrap with app-of-apps from a single root Application
- Manage Envoy Gateway and `demo-api` as child Applications
- All sync targets pulled from this repo

---

## Phases

| #   | Goal                             | Done when (local Docker Desktop)                                                                                                                               |
| --- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 00  | Install Argo CD                  | Helm install succeeds; port-forward reaches Argo CD UI; admin login works                                                                                      |
| 01  | Root app-of-apps                 | `00-root.yaml` applied; UI + `argocd app list` show root Application Healthy/Synced                                                                            |
| 02  | Envoy Gateway                    | Child Application syncs Envoy Gateway; `kubectl get gatewayclass` shows it Ready                                                                               |
| 03  | demo-api                         | Child Application syncs demo-api chart; pods + svc + httproute Healthy; `curl -H "Host: cloud.arguswatcher.net" http://<gateway>/api/` returns expected JSON   |
| 04  | Multi-cluster via ApplicationSet | AKS registered to the EKS-hosted Argo CD; `demo-api` migrated to an ApplicationSet (`clusters` generator) that fans out to both clusters with per-cloud values |

---

## Out of Scope (this stage)

- Multi-cluster Argo CD (single-cluster only for now)
- SSO / RBAC beyond default admin
- Notifications, image updater

---

## Note

### Install - Docker Desktop

```sh
# install dock desktop
# add helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# install into argocd namespace
helm install argocd argo/argo-cd --namespace argocd --create-namespace

# wait for pods to be ready (~1-2 min)
kubectl get pods -n argocd -w
# Ctrl-C once all show Running / 1/1

# get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo

# port-forward the UI
kubectl -n argocd port-forward svc/argocd-server 8081:443

argocd login localhost:8081 --username admin --insecure
```

---

### App-of-apps

```sh
# apply the root Application
kubectl apply -f https://raw.githubusercontent.com/simonangel-fong/k8s-multi-cloud/refs/heads/master/argocd/00-root.yaml
# kubectl apply -f argocd/00-root.yaml
# application.argoproj.io/root created

argocd app sync root
# GROUP        KIND         NAMESPACE  NAME                  STATUS  HEALTH  HOOK  MESSAGE
# argoproj.io  Application  argocd     envoy-gateway-config  Synced                application.argoproj.io/envoy-gateway-config created
# argoproj.io  Application  argocd     envoy-gateway         Synced                application.argoproj.io/envoy-gateway unchanged

argocd app list
# NAME                           CLUSTER                         NAMESPACE             PROJECT  STATUS  HEALTH       SYNCPOLICY  CONDITIONS  REPO                                                    PATH                         TARGET
# argocd/clusters                https://kubernetes.default.svc  argocd                default  Synced  Healthy      Auto-Prune  <none>      https://github.com/simonangel-fong/k8s-multi-cloud.git  argocd/clusters              master
# argocd/demo-api-eks-incluster  https://kubernetes.default.svc  demo-api              default  Synced  Healthy      Auto-Prune  <none>      https://github.com/simonangel-fong/k8s-multi-cloud.git  helm/multicloud-demo-api     master
# argocd/envoy-gateway           https://kubernetes.default.svc  envoy-gateway-system  default  Synced  Healthy      Auto-Prune  <none>      registry-1.docker.io/envoyproxy                                                      v1.2.0
# argocd/envoy-gateway-config    https://kubernetes.default.svc  envoy-gateway-system  default  Synced  Progressing  Auto-Prune  <none>      https://github.com/simonangel-fong/k8s-multi-cloud.git  argocd/envoy-gateway-config  master
# argocd/root                    https://kubernetes.default.svc  argocd                default  Synced  Healthy      Auto-Prune  <none>      https://github.com/simonangel-fong/k8s-multi-cloud.git  argocd/app                   master
```

### Gateway

```sh
# confirm controller running
kubectl get pods -n envoy-gateway-system
# NAME                                                      READY   STATUS    RESTARTS   AGE
# envoy-envoy-gateway-system-eg-5391c79d-79b77768dd-khx4v   2/2     Running   0          3m45s
# envoy-gateway-56cf4769b-jmx5n                             1/1     Running   0          4m3s

kubectl get gatewayclass
# NAME   CONTROLLER                                      ACCEPTED   AGE
# eg     gateway.envoyproxy.io/gatewayclass-controller   True       14m

kubectl get gateway -n envoy-gateway-system
# NAME   CLASS   ADDRESS                                                                      PROGRAMMED   AGE
# eg     eg      a9c8c8f6fe5be4024988c4ea8a504209-2006339220.ca-central-1.elb.amazonaws.com   True         4m43s

# workload up
kubectl get pods,svc -n demo-api
# NAME                                                READY   STATUS    RESTARTS   AGE
# pod/demo-api-multicloud-demo-api-6d57bcbdf4-8tbtp   1/1     Running   0          2m32s
# pod/demo-api-multicloud-demo-api-6d57bcbdf4-bvk8n   1/1     Running   0          2m32s

# NAME                                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# service/demo-api-multicloud-demo-api   ClusterIP   172.20.147.42   <none>        80/TCP    2m32s
kubectl get httproute -n demo-api
# NAME                           HOSTNAMES                    AGE
# demo-api-multicloud-demo-api   ["cloud.arguswatcher.net"]   2m51s
```

---

---

### Multi-cluster ApplicationSet

- `argocd/app/03-demo-api.yaml`:
  - an ApplicationSet with a `clusters` generator scoped by label `workload=demo-api`.
- Per-cloud overrides live in `helm/multicloud-demo-api/values-<cloud>.yaml`, selected by the cluster Secret's `cloud` label.

#### EKS

```sh
argocd app sync clusters
argocd appset list
# NAME             PROJECT  SYNCPOLICY  CONDITIONS                                                                                                                                                                                                                                                             REPO                                                    PATH                      TARGET
# argocd/demo-api  default  nil         [{ParametersGenerated Successfully generated parameters for all Applications 2026-06-24 17:14:52 -0400 EDT True ParametersGenerated} {ResourcesUpToDate All applications have been generated successfully 2026-06-24 18:00:28 -0400 EDT True ApplicationSetUpToDate}]  https://github.com/simonangel-fong/k8s-multi-cloud.git  helm/multicloud-demo-api  master

argocd app list | grep demo-api

GATEWAY_ADDR=$(kubectl get gateway eg -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
curl -H "Host: cloud.arguswatcher.net" "http://${GATEWAY_ADDR}/api/"
# {"app":"k8s-multi-cloud","cloud_provider":"aws","version":"0.1.0"}
```

## Test APP

```sh
# resolve gateway address
GATEWAY_ADDR=$(kubectl get gateway eg -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
echo $GATEWAY_ADDR
# ac23d6ce9322842a49dc57a7eb22a84f-1136175866.ca-central-1.elb.amazonaws.com
curl -H "Host: cloud.arguswatcher.net" "http://${GATEWAY_ADDR}/api/"
# {"app":"k8s-multi-cloud","cloud_provider":"local","version":"0.1.0"}
```

#### AKS

```sh
# 1. Pull AKS credentials into kubeconfig
az aks get-credentials --resource-group multi-cloud-k8s-dev --name multi-cloud-k8s-dev --overwrite-existing

# 2. Register the AKS context with ArgoCD
argocd cluster add multi-cloud-k8s-dev --name multi-cloud-k8s-dev

# 3. Label so the ApplicationSet picks it up
kubectl -n argocd label secret cluster-<server-hash> cloud=azure workload=demo-api


# Add AKS later
argocd cluster add <aks-kubectx> --name aks-prod
# 3) label the new cluster Secret so the generator picks it up:
kubectl -n argocd label secret aks-prod cloud=azure workload=demo-api
# ApplicationSet auto-creates demo-api-aks-prod; cloud_provider returns "azure".
```

### Test APP

```sh
GATEWAY_ADDR=$(kubectl get gateway eg -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
echo $GATEWAY_ADDR
'20.48.140.60'
curl -H "Host: cloud.arguswatcher.net" "http://20.48.140.60/api/"
# {"app":"k8s-multi-cloud","cloud_provider":"azure","version":"0.1.0"}
```

---

## Runbook

```sh
kubectl patch gatewayclass eg --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```
