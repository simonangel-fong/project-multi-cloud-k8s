# Documentation: Cloudflare Load Balancing

[Back](../README.md)

- [Documentation: Cloudflare Load Balancing](#documentation-cloudflare-load-balancing)
  - [Cloudflare Load Balancing](#cloudflare-load-balancing)
  - [Phases](#phases)
  - [Development](#development)
    - [Variables](#variables)
    - [Resolve origin endpoints](#resolve-origin-endpoints)
    - [Provision](#provision)
    - [Verify](#verify)

---

## Cloudflare Load Balancing

Use Cloudflare Load Balancing to front the EKS and AKS Envoy Gateway public LBs behind a single hostname (`cloud.arguswatcher.net`) with health-checked failover.

- Installation

| Env | Method                                        |
| --- | --------------------------------------------- |
| dev | Cloudflare zone `arguswatcher.net`, Terraform |

- **Repo Layout**

```txt
infra/cloudflare/
  01_variables.tf   # project_name, env, zone, hostname, origin endpoints
  02_locals.tf      # common_name, naming
  03_providers.tf   # cloudflare provider + s3 backend
  04_outputs.tf     # final hostname, LB id, pool ids
  05_main.tf        # monitor + pools + load balancer + DNS record
  backend.hcl       # shared bucket; key=multi-cloud-k8s/cloudflare/terraform.tfstate
```

> Origin endpoints (EKS ELB hostname, AKS LB IP) come from the Envoy Gateway `gateway.status.addresses[0].value` in each cluster

- **Resources**

| Resource       | Cloudflare type                    | Purpose                                                   |
| -------------- | ---------------------------------- | --------------------------------------------------------- |
| `monitor-http` | `cloudflare_load_balancer_monitor` | HTTP probe on `/api/` with `Host: cloud.arguswatcher.net` |
| `pool-aws`     | `cloudflare_load_balancer_pool`    | Origin = EKS Envoy Gateway ELB hostname                   |
| `pool-azure`   | `cloudflare_load_balancer_pool`    | Origin = AKS Envoy Gateway LB IP                          |
| `lb-cloud`     | `cloudflare_load_balancer`         | Steering = `random`; both pools as default                |
| `record-cloud` | `cloudflare_record` (proxied)      | `cloud.arguswatcher.net` → LB, TLS at edge                |

- **Steering**

`random` across both pools. Cloudflare picks an available pool per request; unhealthy pools drop out automatically via the monitor. No geo affinity in this phase.

- **TLS**

Edge-terminated by Cloudflare (proxied = `true`). Origins stay HTTP on port 80 — the Envoy Gateway listener does not yet terminate TLS. Cloudflare → origin uses "Flexible" SSL initially; upgrade to "Full" once origins have certs.

- Goals

- Single public hostname for both clouds
- Active/active with health-based failover
- TLS terminated at Cloudflare edge
- All resources declarative in `infra/cloudflare`, state in the same S3 bucket as `multi-cloud-kube`

---

## Phases

| #   | Goal                       | Done when                                                                |
| --- | -------------------------- | ------------------------------------------------------------------------ |
| 00  | Scaffold + backend         | `terraform init` succeeds; state object at s3                            |
| 01  | Provider + zone wiring     | `cloudflare` provider authenticated;                                     |
| 02  | Health monitor             | Monitor created; shows healthy probes against both origins               |
| 03  | Origin pools (AWS + Azure) | Both pools `healthy` in CF dashboard;                                    |
| 04  | Load balancer + DNS record | `dig cloud.arguswatcher.net`; `curl https://cloud.arguswatcher.net/api/` |
| 05  | Failover validation        | traffic shifts to one cloud; `cloud_provider` in JSON flips              |

---

## Development

### Variables

Set in `infra/cloudflare/terraform.tfvars`:

```hcl
env                  = "dev"
cf_zone_name         = "arguswatcher.net"
hostname             = "cloud"
aws_origin_hostname  = "<eks-envoy-gateway-elb-hostname>"   # from kubectl get gateway eg -n envoy-gateway-system
azure_origin_address = "<aks-envoy-gateway-ip>"
```

Auth via env var:

```sh
export CLOUDFLARE_API_TOKEN=...   # scoped: Zone:Read, DNS:Edit, Load Balancing:Edit on arguswatcher.net
```

### Resolve origin endpoints

```sh
# EKS
aws eks update-kubeconfig --region ca-central-1 --name multi-cloud-k8s-dev
kubectl get gateway eg -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}'

# AKS
az aks get-credentials --resource-group multi-cloud-k8s-dev --name multi-cloud-k8s-dev --overwrite-existing
kubectl get gateway eg -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}'
# 20.48.140.60
```

### Provision

```sh
terraform -chdir=infra/cloudflare init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/cloudflare fmt && terraform -chdir=infra/cloudflare validate
terraform -chdir=infra/cloudflare plan
terraform -chdir=infra/cloudflare apply -auto-approve

terraform -chdir=infra/cloudflare destroy -auto-approve
```

### Verify

```sh
dig +short cloud.arguswatcher.net
# <Cloudflare anycast IPs>
```

Run the demo script — hits the LB once per second and prints a live tally of which cloud answered:

```sh
./scripts/test-url.sh
# 14:32:01  aws    (aws=1 azure=0 error=0)
# 14:32:02  azure  (aws=1 azure=1 error=0)
# 14:32:03  azure  (aws=1 azure=2 error=0)
# ...
# Final tally:
#   aws    61
#   azure  59
```

Env overrides: `DURATION` (seconds, default 120), `SLEEP` (seconds between requests, default 1), `URL` (target, default `https://cloud.arguswatcher.net/api/`).

```sh
curl -v -H "Host: cloud.arguswatcher.net" "http://20.200.88.217/api/"
curl -v -H "Host: cloud.arguswatcher.net" "http://a4e79dabf1d6b41919543e2410b20307-31536122.ca-central-1.elb.amazonaws.com/api/"
```
