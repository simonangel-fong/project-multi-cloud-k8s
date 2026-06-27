# Documentation: Helm Chart

[Back](../README.md)

- [Documentation: Helm Chart](#documentation-helm-chart)
  - [Design](#design)
  - [Phases](#phases)
  - [Development](#development)
    - [App](#app)
    - [Gateway API in EKS](#gateway-api-in-eks)

---

Helm chart to deploy `demo-api` on Kubernetes (local + EKS).

- **Chart path:** `helm/multicloud-demo-api/`
- **Image:** `simonangelfong/multicloud-demo-api:0.1.1`

## Design

- Target Environments

| Env   | Cluster                   | Purpose                       |
| ----- | ------------------------- | ----------------------------- |
| local | Docker Desktop Kubernetes | Chart authoring & smoke tests |
| aws   | EKS                       | Full scaling + routing tests  |

- App Endpoints (recap)

| Method | Path       | Purpose                              |
| ------ | ---------- | ------------------------------------ |
| GET    | `/api/`    | App + version + cloud JSON           |
| GET    | `/env/`    | `VERSION`, `CLOUD_PROVIDER` from env |
| GET    | `/healthz` | `ok` — used for probes               |

- Kubernetes Resources

| Resource   | Key settings                                                                                    |
| ---------- | ----------------------------------------------------------------------------------------------- |
| Deployment | replicas: 2; containerPort: 8080; readiness + liveness on `/healthz`; CPU/mem requests & limits |
| Service    | type: `ClusterIP`; port: 80 → 8080                                                              |
| HPA        | min: 2, max: 10; target CPU: 40%; stabilization: 60s                                            |
| HTTPRoute  | hostname: `cloud.arguswatcher.net`; path: `/api/`                                               |

Env vars `VERSION` and `CLOUD_PROVIDER` set via `values.yaml`.

---

## Phases

| #   | Goal            | Done when (local Docker Desktop)                                          |
| --- | --------------- | ------------------------------------------------------------------------- |
| 00  | Init chart      | `helm create` scaffold; `helm install` succeeds; single nginx Deployment; |
| 01  | Deployment      | Swap to `demo-api` image; 2 pods with env vars set; `curl` api paths      |
| 02  | Service         | `ClusterIP` Service routes to pods;                                       |
| 03  | HPA + HTTPRoute | HPA and HTTPRoute objects;                                                |

---

## Development

### App

```sh
cd helm
helm lint helm/multicloud-demo-api
# chart(s) linted, 0 chart(s) failed
helm template test helm/multicloud-demo-api

# switch context (if not already)
kubectl config use-context docker-desktop

# install
helm upgrade -i demo helm/multicloud-demo-api

# confirm pod running
kubectl get pods,svc -l app.kubernetes.io/instance=demo
# NAME                                            READY   STATUS    RESTARTS   AGE
# pod/demo-multicloud-demo-api-69f566cc49-ckg4d   1/1     Running   0          25s
# pod/demo-multicloud-demo-api-69f566cc49-m8nrn   1/1     Running   0          25s

# NAME                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
# service/demo-multicloud-demo-api   ClusterIP   10.103.46.209   <none>        80/TCP    25s

# env vars present
kubectl describe pod -l app.kubernetes.io/instance=demo | grep -E "VERSION|CLOUD_PROVIDER
"
    #   CLOUD_PROVIDER:  local
    #   VERSION:         0.1.0
    #   CLOUD_PROVIDER:  local
    #   VERSION:         0.1.0

# port-forward and open browser
kubectl port-forward svc/demo-multicloud-demo-api 8080:80


curl http://localhost:8080/api/
# {"app":"k8s-multi-cloud","cloud_provider":"local","version":"0.1.0"}

curl http://localhost:8080/env/
# {"CLOUD_PROVIDER":"local","VERSION":"0.1.0"}

curl http://localhost:8080/healthz
# ok

# cleanup when done
helm uninstall demo
```

---

### Gateway API in EKS

```sh
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

helm upgrade --install demo helm/multicloud-demo-api --set hpa.enabled=true --set httpRoute.enabled=true

kubectl get httproute
# NAME                       HOSTNAMES                    AGE
# demo-multicloud-demo-api   ["cloud.arguswatcher.net"]   14s

```
