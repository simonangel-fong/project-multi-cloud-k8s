# App: demo-api

A minimal RESTful API for validating multi-cloud Kubernetes deployments.

- **Language:** Go
- **Framework:** Gin

## Endpoints

| Method | Path       | Response                                                             |
| ------ | ---------- | -------------------------------------------------------------------- |
| GET    | `/api/`    | `{"app":"k8s-multi-cloud","version":"0.1.0","cloud_provider":"AWS"}` |
| GET    | `/healthz` | `ok`                                                                 |
| GET    | `/env/`    | `{"VERSION":"0.1.0","CLOUD_PROVIDER":"AWS"}`                         |

## Env Vars

- `VERSION` — app version, surfaced at `/api/` and `/env/`
- `CLOUD_PROVIDER` — target cloud (e.g. `AWS`, `Azure`), surfaced at `/api/` and `/env/`

## Packaging

- Multi-stage `Dockerfile` for a minimal runtime image.

## File Structure

```
app/
  demo-api/          # Go source
  Dockerfile
  docker-compose.yaml
  README.md
```

---

## Phases

| #   | Goal       | Done when                                                                                                                       |
| --- | ---------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 00  | Init       | Go project scaffolded at `app/demo-api/`; hello-world responds on `:8080` locally                                               |
| 01  | `/env/`    | Returns `VERSION` and `CLOUD_PROVIDER` from env; verified locally                                                               |
| 02  | `/api/`    | Returns app/version/cloud JSON; verified locally                                                                                |
| 03  | `/healthz` | Returns `ok`; verified locally                                                                                                  |
| 04  | Dockerfile | Builds multi-stage image; `docker compose` run swaps `VERSION` (`0.1.0`/`1.0.0`) and `CLOUD_PROVIDER` (`aws`/`azure`) correctly |

---

## Out of Scope (this stage)

- Unit tests
- Security scanning
- Production hardening — goal is _make it work_, not _make it right_

---

## Note

### API

```sh
cd app/demo-api

go mod init demo-api
go get github.com/gin-gonic/gin
go mod tidy

$env:VERSION="0.1.0"; $env:CLOUD_PROVIDER="AWS"; go run .
curl http://localhost:8080/env/
# {"CLOUD_PROVIDER":"AWS","VERSION":"0.1.0"}

curl http://localhost:8080/api/
# {"app":"k8s-multi-cloud","cloud_provider":"AWS","version":"0.1.0"}

curl http://localhost:8080/healthz
# ok
```

---

## Docker Image

```sh
cd app
docker compose up -d --build

curl http://localhost:8081/api/
# {"app":"k8s-multi-cloud","cloud_provider":"aws","version":"0.1.0"}

curl http://localhost:8082/api/
# {"app":"k8s-multi-cloud","cloud_provider":"azure","version":"1.0.0"}

curl http://localhost:8081/healthz
# ok

# Teardown when done:
docker compose down -v
```

---

## Docker push

```sh
cd app

# 1. login (once)
docker login

# 2. build with the target tag
docker build -t simonangelfong/multicloud-demo-api:0.1.0 .

# 3. (optional) also tag as latest
docker tag simonangelfong/multicloud-demo-api:0.1.0 simonangelfong/multicloud-demo-api:latest

# 4. push
docker push simonangelfong/multicloud-demo-api:0.1.0
docker push simonangelfong/multicloud-demo-api:latest

# test
docker run -d --name multicloud-demo-api --rm -p 8080:8080 -e VERSION=0.1.0 -e CLOUD_PROVIDER=aws simonangelfong/multicloud-demo-api:0.1.0
# then in another terminal:
curl http://localhost:8080/api/
# {"app":"k8s-multi-cloud","cloud_provider":"aws","version":"0.1.0"}

docker stop multicloud-demo-api
docker rm multicloud-demo-api
```
