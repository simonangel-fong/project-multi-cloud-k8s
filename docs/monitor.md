# Monitoring: Grafana Cloud for k8s-multi-cloud

Ship metrics, logs, events, and energy data from EKS and AKS to a single Grafana Cloud stack via the `grafana/k8s-monitoring` Helm chart (Alloy-based, multi-collector).

## Installation

| Env | Method                                                                                                                           |
| --- | -------------------------------------------------------------------------------------------------------------------------------- |
| dev | Grafana Cloud free stack; `k8s-monitoring` chart installed per cluster via ArgoCD; Grafana Cloud Secret provisioned by Terraform |

## Data flow

```txt
demo-api pod  ──/metrics───┐
kubelet/cAdvisor + events ─┼──► Alloy collectors (DaemonSet / StatefulSet / Singleton) ──► Grafana Cloud
container stdout/stderr  ──┘                                                                (Prom + Loki + Fleet Mgmt)
```

| Signal                | Source                          | Collector preset            | Grafana Cloud backend    |
| --------------------- | ------------------------------- | --------------------------- | ------------------------ |
| cluster metrics       | kube-state-metrics, cAdvisor    | `alloy-metrics` (clustered) | Prometheus               |
| host metrics          | node-exporter, windows-exporter | `alloy-metrics`             | Prometheus               |
| cluster events        | k8s events API                  | `alloy-singleton`           | Prometheus / Loki        |
| pod logs              | container stdout/stderr         | `alloy-logs` (daemonset)    | Loki                     |
| energy                | Kepler                          | `alloy-metrics`             | Prometheus               |
| remote-config / fleet | Alloy fleet management          | all collectors              | Grafana Cloud Fleet Mgmt |

## Repo layout

```
infra/multi-cloud-kube/
  01_variables.tf       # gc_* vars (urls, usernames, token — token is sensitive)
  08_monitoring.tf      # monitoring ns + grafana-cloud Secret per cluster
argocd/app/
  04-grafana-k8s-monitoring.yaml   # ApplicationSet — k8s-monitoring chart per cluster
```

> Grafana Cloud creds live in a single `grafana-cloud` Secret in the `monitoring` namespace per cluster, created by Terraform. The chart references it via `destinations[].secret.{name,namespace}` and `auth.usernameKey/passwordKey` — nothing sensitive lives in Git.

## Secret schema

`monitoring/grafana-cloud` (Opaque):

| Key              | Source variable     | Consumed by                                            |
| ---------------- | ------------------- | ------------------------------------------------------ |
| `PROM_URL`       | `gc_prom_url`       | Alloy `envFrom` → `urlFrom: sys.env("PROM_URL")`       |
| `LOGS_URL`       | `gc_logs_url`       | Alloy `envFrom` → `urlFrom: sys.env("LOGS_URL")`       |
| `FLEET_URL`      | `gc_fleet_url`      | Alloy `envFrom` → `urlFrom: sys.env("FLEET_URL")`      |
| `prom_username`  | `gc_prom_username`  | `destinations[grafana-cloud-metrics].auth.usernameKey` |
| `prom_password`  | `gc_token`          | `destinations[grafana-cloud-metrics].auth.passwordKey` |
| `logs_username`  | `gc_logs_username`  | `destinations[grafana-cloud-logs].auth.usernameKey`    |
| `logs_password`  | `gc_token`          | `destinations[grafana-cloud-logs].auth.passwordKey`    |
| `fleet_username` | `gc_fleet_username` | `collectorCommon.alloy.remoteConfig.auth.usernameKey`  |
| `fleet_password` | `gc_token`          | `collectorCommon.alloy.remoteConfig.auth.passwordKey`  |

Two key conventions in one Secret:

- **UPPER_CASE** keys mount as env vars via `collectorCommon.alloy.envFrom: [{secretRef: {name: grafana-cloud}}]` and resolve through `urlFrom: sys.env("...")` — keeps URLs out of Git.
- **lower_case** keys feed the chart's `auth.usernameKey` / `auth.passwordKey` lookup.

Same single token is used for all three scopes — it's how Grafana Cloud's "Kubernetes Integration" install flow issues it.

## Goals

- One Grafana Cloud stack, both clusters reporting in parallel
- No plaintext tokens in Git; chart values reference an existing Secret
- `cluster=<eks|aks>` label automatic via ArgoCD `clusters` generator
- Same GitOps pattern as `envoy-gateway` and `demo-api` — ApplicationSet at sync-wave 3

---

## Phases

| #   | Goal                                | Done when                                                                                                                    |
| --- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 00  | Grafana Cloud stack                 | Stack created at grafana.com; "Kubernetes" integration page surfaces Prom / Loki / Fleet URLs + usernames + one access token |
| 01  | Terraform vars + Secret             | `gc_*` vars set in `terraform.tfvars`; `terraform apply` creates `monitoring/grafana-cloud` Secret on EKS                    |
| 02  | update api to enable metric and log | `demo-api` exposes Prometheus `/metrics`; access logs are JSON on stdout                                                     |
| 03  | install alloy via helm              | `helm install` of `grafana/k8s-monitoring` on EKS reaches Ready; `demo-api` `up`/`http_requests_total` and JSON logs appear in Grafana Cloud |
| 04  | install alloy via helm + arogcd     | confirm in app-of-apps                                                                                                       |
| 05  | Demo dashboard                      | Out-of-the-box "Kubernetes / Cluster overview" dashboard split by `cluster`; energy panels populated                         |

---

## Out of Scope (this stage)

- Self-hosted Prometheus / Loki / Tempo
- Application-level RED metrics + traces from `demo-api` (separate chart wiring)
- Alerts, SLOs, on-call routing
- Secrets via External Secrets Operator (Terraform-managed for now)
- mTLS / private link to Grafana Cloud

---

## Note

### Grafana Cloud (phase 00)

1. Sign up → create stack `multi-cloud-k8s-dev`.
2. Connections → **Kubernetes** → "Install integration" → copy the generated values block. Capture:
   - Prometheus remote-write URL + username (numeric instance id)
   - Loki push URL + username
   - Fleet management URL + username
   - One access token (`glc_...`) — used for all three

### Terraform Secret (phase 01)

Add to `infra/multi-cloud-kube/terraform.tfvars` (gitignored):

```hcl
gc_prom_url       = ""
gc_prom_username  = ""
gc_logs_url       = ""
gc_logs_username  = ""
gc_fleet_url      = ""
gc_fleet_username = ""
gc_token          = "glc_xxx"   # sensitive
```

Apply:

```sh
terraform -chdir=infra/multi-cloud-kube apply
kubectl -n monitoring get secret grafana-cloud -o jsonpath='{.data}' | jq 'keys'

```

### demo-api: metrics + logs

- add `GET /metrics`

Verify locally:

```sh
# local run
cd app/demo-api
$env:VERSION="0.1.0"; $env:CLOUD_PROVIDER="AWS"; go run .

docker compose -f app/docker-compose.yaml up --build -d
curl -s localhost:8081/api/ 
# {"app":"k8s-multi-cloud","cloud_provider":"aws","version":"0.1.0"}

# confirm: metric
curl -s localhost:8081/metrics | grep http_requests_total
# confirm: log
docker compose -f app/docker-compose.yaml logs aws | tail -n 5  
# aws-1  | {"time":"2026-06-26T19:02:25.557336696Z","level":"INFO","msg":"starting demo-api","addr":":8080","version":"0.1.0","cloud_provider":"aws"}
# aws-1  | {"time":"2026-06-26T19:03:01.615380608Z","level":"INFO","msg":"http_request","method":"GET","route":"/api/","path":"/api/","status":200,"latency_ms":0,"client_ip":"172.19.0.1"}

cd app
docker build -t simonangelfong/multicloud-demo-api:0.1.1 .
docker tag simonangelfong/multicloud-demo-api:0.1.1 simonangelfong/multicloud-demo-api:latest

docker push simonangelfong/multicloud-demo-api:0.1.1
docker push simonangelfong/multicloud-demo-api:latest

docker run -d --name multicloud-demo-api --rm -p 8080:8080 -e VERSION=0.1.1 -e CLOUD_PROVIDER=aws simonangelfong/multicloud-demo-api:0.1.1

curl http://localhost:8080/api/
curl -s localhost:8081/metrics

docker logs multicloud-demo-api

docker stop multicloud-demo-api
docker rm multicloud-demo-api
```

### Alloy via Helm (phase 03)


```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana

helm upgrade --install grafana-k8s-monitoring grafana/k8s-monitoring --version 4.1.6 --namespace monitoring -f helm/k8s-monitoring/values-eks.yaml --rollback-on-failure --timeout 5m

helm list -A
# NAME                                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                 APP VERSION
# argocd                                  argocd          1               2026-06-26 16:33:01.2662609 -0400 EDT   deployed        argo-cd-9.7.0         v3.4.4
# grafana-k8s-monitoring                  monitoring      2               2026-06-26 17:10:22.8234459 -0400 EDT   deployed        k8s-monitoring-4.1.6  4.1.6
# grafana-k8s-monitoring-alloy-logs       monitoring      1               2026-06-26 21:02:20.416701352 +0000 UTC deployed        alloy-1.10.0          v1.17.0
# grafana-k8s-monitoring-alloy-metrics    monitoring      1               2026-06-26 21:02:20.417036796 +0000 UTC deployed        alloy-1.10.0          v1.17.0
# grafana-k8s-monitoring-alloy-singleton  monitoring      1               2026-06-26 21:02:20.910274373 +0000 UTC deployed        alloy-1.10.0          v1.17.0
```

Verify pods:

```sh
kubectl -n monitoring get pods

kubectl -n monitoring get pod grafana-k8s-monitoring-alloy-metrics-0 -o jsonpath='{range .spec.containers[?(@.name=="alloy")].env[*]}{.name}{"\n"}{end}'
# ALLOY_DEPLOY_MODE
# HOSTNAME
# K8S_NODE_NAME
# NAMESPACE
# POD_NAME
# GCLOUD_RW_API_KEY

kubectl -n monitoring logs -l app.kubernetes.io/name=alloy-metrics --tail=50 | grep -E "invalid token|unsupported|remote_write|error"
# none
```

Verify in Grafana Cloud:

```promql
# Cluster heartbeat — should be 1
up{cluster="eks"}

# demo-api scrape via annotation autodiscovery
http_requests_total{cluster="eks"}
```

```logql
# demo-api JSON access logs
{cluster="eks", namespace="demo-api", pod=~".*demo-api.*"} | json
```

Uninstall (rollback):

```sh
helm uninstall grafana-k8s-monitoring -n monitoring
```
