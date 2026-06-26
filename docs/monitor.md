# Monitoring: Grafana Cloud for k8s-multi-cloud

Ship metrics, logs, events, and energy data from EKS and AKS to a single Grafana Cloud stack via the `grafana/k8s-monitoring` Helm chart (Alloy-based, multi-collector).

## Installation

| Env | Method                                                                     |
| --- | -------------------------------------------------------------------------- |
| dev | Grafana Cloud free stack; `k8s-monitoring` chart installed per cluster via ArgoCD; Grafana Cloud Secret provisioned by Terraform |

## Data flow

```txt
demo-api pod  ──/metrics───┐
kubelet/cAdvisor + events ─┼──► Alloy collectors (DaemonSet / StatefulSet / Singleton) ──► Grafana Cloud
container stdout/stderr  ──┘                                                                (Prom + Loki + Fleet Mgmt)
```

| Signal              | Source                              | Collector preset             | Grafana Cloud backend         |
| ------------------- | ----------------------------------- | ---------------------------- | ----------------------------- |
| cluster metrics     | kube-state-metrics, cAdvisor        | `alloy-metrics` (clustered)  | Prometheus                    |
| host metrics        | node-exporter, windows-exporter     | `alloy-metrics`              | Prometheus                    |
| cluster events      | k8s events API                      | `alloy-singleton`            | Prometheus / Loki             |
| pod logs            | container stdout/stderr             | `alloy-logs` (daemonset)     | Loki                          |
| energy              | Kepler                              | `alloy-metrics`              | Prometheus                    |
| remote-config / fleet | Alloy fleet management            | all collectors               | Grafana Cloud Fleet Mgmt      |

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

| Key              | Source variable      | Consumed by                                                   |
| ---------------- | -------------------- | ------------------------------------------------------------- |
| `PROM_URL`       | `gc_prom_url`        | Alloy `envFrom` → `urlFrom: sys.env("PROM_URL")`              |
| `LOGS_URL`       | `gc_logs_url`        | Alloy `envFrom` → `urlFrom: sys.env("LOGS_URL")`              |
| `FLEET_URL`      | `gc_fleet_url`       | Alloy `envFrom` → `urlFrom: sys.env("FLEET_URL")`             |
| `prom_username`  | `gc_prom_username`   | `destinations[grafana-cloud-metrics].auth.usernameKey`        |
| `prom_password`  | `gc_token`           | `destinations[grafana-cloud-metrics].auth.passwordKey`        |
| `logs_username`  | `gc_logs_username`   | `destinations[grafana-cloud-logs].auth.usernameKey`           |
| `logs_password`  | `gc_token`           | `destinations[grafana-cloud-logs].auth.passwordKey`           |
| `fleet_username` | `gc_fleet_username`  | `collectorCommon.alloy.remoteConfig.auth.usernameKey`         |
| `fleet_password` | `gc_token`           | `collectorCommon.alloy.remoteConfig.auth.passwordKey`         |

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

| #   | Goal                                | Done when                                                                                                                                       |
| --- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 00  | Grafana Cloud stack                 | Stack created at grafana.com; "Kubernetes" integration page surfaces Prom / Loki / Fleet URLs + usernames + one access token                    |
| 01  | Terraform vars + Secret             | `gc_*` vars set in `terraform.tfvars`; `terraform apply` creates `monitoring/grafana-cloud` Secret on EKS                                       |
| 02  | ApplicationSet                      | `04-grafana-k8s-monitoring.yaml` synced; `kubectl -n monitoring get pods` shows `alloy-metrics`, `alloy-logs`, `alloy-singleton`, kube-state-metrics, node-exporter, opencost, kepler all Ready |
| 03  | Signals visible in Grafana Cloud    | Explore → Prometheus shows `up{cluster="multi-cloud-k8s-dev"}`; Loki shows `{cluster="multi-cloud-k8s-dev"}`; Fleet Mgmt UI lists the Alloy instances |
| 04  | Add AKS                             | AKS module + provider uncommented; `08_monitoring.tf` AKS block uncommented; second cluster appears in dashboards with its own `cluster` label  |
| 05  | Demo dashboard                      | Out-of-the-box "Kubernetes / Cluster overview" dashboard split by `cluster`; energy panels populated                                            |

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
# ["FLEET_URL","LOGS_URL","PROM_URL","fleet_password","fleet_username","logs_password","logs_username","prom_password","prom_username"]
```

> The token also lands in the S3-backed Terraform state. State is already encrypted + access-restricted; that's the accepted tradeoff vs. ESO / SOPS for this stage.

### ApplicationSet (phase 02)

`argocd/app/04-grafana-k8s-monitoring.yaml` — `clusters` generator on `workload=demo-api`, sync-wave `3` (runs after envoy-gateway-config and demo-api). The template:

- Sets `cluster.name: '{{ .name }}'` so each cluster's Secret label flows through as the `cluster=` label on every series.
- Mounts the `grafana-cloud` Secret on every Alloy collector via `collectorCommon.alloy.envFrom`, and resolves URLs via `urlFrom: sys.env("PROM_URL"|"LOGS_URL"|"FLEET_URL")` — **no URLs in Git**.
- Sets `destinations[].secret.{name: grafana-cloud, namespace: monitoring}` + `auth.usernameKey/passwordKey` for Prom and Loki — no plaintext credentials in Git.
- OpenCost is disabled in this phase: its `prometheus.external.url` does not support `urlFrom`, so re-enabling it requires either ESO or a Terraform-rendered ConfigMap.

Verify:

```sh
argocd app list | grep grafana-k8s-monitoring
kubectl -n monitoring get pods
# alloy-metrics-0                          2/2 Running
# alloy-logs-xxxxx                         2/2 Running   (one per node)
# alloy-singleton-xxxxx                    2/2 Running
# grafana-k8s-monitoring-kube-state-metrics-xxxxx   1/1 Running
# grafana-k8s-monitoring-prometheus-node-exporter-xxxxx  1/1 Running   (one per node)
# grafana-k8s-monitoring-kepler-xxxxx      1/1 Running   (one per node)
```

### Signals in Grafana Cloud (phase 03)

Explore queries:

```promql
# pods up per cluster
sum by (cluster) (kube_pod_status_ready{condition="true"})

# node CPU
sum by (cluster, instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))
```

```logql
{cluster="multi-cloud-k8s-dev", namespace="demo-api"}
```

### Add AKS (phase 04)

1. Uncomment the AKS module in [05_aws_main.tf](../infra/multi-cloud-kube/06_az_main.tf) + provider block in [03_providers.tf](../infra/multi-cloud-kube/03_providers.tf).
2. Uncomment the AKS block in [08_monitoring.tf](../infra/multi-cloud-kube/08_monitoring.tf).
3. Register AKS with ArgoCD and label its cluster Secret (see [argocd.md](argocd.md#multi-cluster-applicationset)): `kubectl -n argocd label secret aks-cluster cloud=azure workload=demo-api`.
4. ApplicationSet auto-generates the second app; new `cluster` label appears in Grafana Cloud within a minute.

---

## Runbook

```sh
# Force a config refresh after editing the ApplicationSet
argocd app sync <cluster>-04-grafana-k8s-monitoring

# Inspect what Alloy is actually scraping
kubectl -n monitoring port-forward sts/alloy-metrics 12345:12345
# http://localhost:12345

# Rotate the Grafana Cloud token
# 1. Issue a new token in Grafana Cloud → Access Policies
# 2. Update gc_token in terraform.tfvars
# 3. terraform apply  (Secret updated in-place)
# 4. kubectl -n monitoring rollout restart sts/alloy-metrics ds/alloy-logs sts/alloy-singleton
```
