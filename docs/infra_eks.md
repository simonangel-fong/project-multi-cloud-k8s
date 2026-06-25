```sh
terraform -chdir=infra/aws init -backend-config=backend.hcl -reconfigure
terraform -chdir=infra/aws fmt && terraform -chdir=infra/aws validate
terraform -chdir=infra/aws plan
terraform -chdir=infra/aws apply -auto-approve

terraform -chdir=infra/aws destroy -auto-approve

aws eks delete-addon --cluster-name multi-cloud-k8s-dev --addon-name kube-proxy

ws eks list-addons --cluster-name multi-cloud-k8s-dev
```

---

## Networking - Design

- VPC cidr range must be between
  - `/16` (65,536 IP addresses)
  - `/28` (16 IP addresses)
- VPC CIDR: `10.0.0.0/16`

| Subnet  | AZ            | CIDR          | Usable IPs |
| ------- | ------------- | ------------- | ---------- |
| public  | ca-central-1a | 10.0.0.0/24   | 251        |
| public  | ca-central-1b | 10.0.1.0/24   | 251        |
| private | ca-central-1a | 10.0.64.0/18  | 16,379     |
| private | ca-central-1b | 10.0.128.0/18 | 16,379     |
| private | ca-central-1d | 10.0.192.0/18 | 16,379     |
