# Plan: Migrate to Podman + Terraform (Simple & Industry Standard Options)

## Context

The repo is a sum calculator microservice app (FastAPI backend + Nginx frontend) currently deployed on GKE via `gcloud` shell scripts and Docker. The user is learning K8s and Podman and wants to:
1. Replace Docker with **Podman** for container builds
2. Replace shell scripts with **Terraform** for infra provisioning
3. Support **local dev** (Podman + kind) and **prod** (GCP GKE)

### Bugs to fix (both options)
- `frontend/index.html:55` — hardcoded backend IP `34.74.94.246`
- `network-policy/backend-access-policy.yaml:30` — port `80` should be `8080` (NetworkPolicy operates at pod level, backend listens on 8080)
- `load_test.py` — hardcoded IP `104.196.10.15`
- `Scripts/rollout.sh` — references `fastapi-app` but deployment is named `backend-app`

### Core architecture fix (both options)
The frontend JS calls a hardcoded external IP directly from the browser. Fix: make Nginx reverse-proxy `/api/*` requests to the backend K8s service via cluster DNS. The browser then uses relative URLs — no hardcoded IPs.

---

## Option A: Simple (Beginner-Friendly)

**Philosophy:** Minimal new concepts. Podman as Docker drop-in, flat Terraform config, keep raw K8s YAML, use `kubectl apply`.

### Directory Structure
```
kubernetes/
├── backend/
│   ├── main.py                         # unchanged
│   ├── requirements.txt                # unchanged
│   └── Containerfile                   # renamed from Dockerfile
├── frontend/
│   ├── index.html                      # fix: relative URL /api/add
│   ├── nginx.conf                      # fix: add /api/ reverse proxy
│   ├── favicon.ico                     # unchanged
│   └── Containerfile                   # renamed from Dockerfile
├── k8s/                                # all manifests consolidated
│   ├── namespace.yaml
│   ├── backend-deployment.yaml         # image ref updated
│   ├── backend-service.yaml            # NodePort for dev, LoadBalancer for prod
│   ├── frontend-deployment.yaml        # image ref updated
│   ├── frontend-service.yaml           # NodePort for dev, LoadBalancer for prod
│   ├── backend-hpa.yaml               # moved from hpa/
│   ├── frontend-hpa.yaml              # moved from hpa/
│   └── backend-network-policy.yaml    # moved, port fixed to 8080
├── terraform/
│   ├── main.tf                         # kind (dev) or GKE (prod) via conditionals
│   ├── variables.tf                    # environment, project_id, region
│   ├── outputs.tf                      # kubeconfig command, cluster endpoint
│   ├── dev.tfvars                      # local kind settings
│   └── prod.tfvars                     # GCP GKE settings
├── scripts/
│   ├── build.sh                        # podman build + kind load / GCR push
│   ├── deploy.sh                       # kubectl apply in order
│   └── dev-setup.sh                    # one-command local bootstrap
├── load_test.py                        # fix: env var for host
├── README.md                           # rewritten
└── .gitignore                          # add terraform state files
```

### What changes

| File | Change |
|------|--------|
| `frontend/index.html:55` | `http://34.74.94.246/add?a=...` → `/api/add?a=...` |
| `frontend/nginx.conf` | Add `location /api/ { proxy_pass http://backend-app-service.mlops.svc.cluster.local:80/; }` |
| `backend/Dockerfile` → `backend/Containerfile` | Rename only |
| `frontend/Dockerfile` → `frontend/Containerfile` | Rename only |
| `network-policy` YAML | Port `80` → `8080` |
| `load_test.py` | Use `os.environ.get("TARGET_HOST", "http://localhost:8080")` |
| K8s deployment YAMLs | Update image refs to local build names |
| K8s service YAMLs | Default to `NodePort`, comment for `LoadBalancer` in prod |

### New files
| File | Purpose |
|------|---------|
| `terraform/main.tf` | `kind` provider for dev, `google` provider for prod (conditional) |
| `terraform/variables.tf` | Input variables: environment, project_id, region, cluster_name |
| `terraform/outputs.tf` | Cluster endpoint, kubeconfig command |
| `terraform/dev.tfvars` | `environment = "dev"`, cluster_name |
| `terraform/prod.tfvars` | `environment = "prod"`, GCP project, region |
| `scripts/build.sh` | `podman build` + `kind load` (dev) or `podman push` to GCR (prod) |
| `scripts/deploy.sh` | `kubectl apply` all manifests in order |
| `scripts/dev-setup.sh` | Runs terraform → build → deploy → port-forward instructions |

### Delete
- Root-level `main.py`, `Dockerfile`, `requirements.txt` (unused Hello World test app)
- `Scripts/create_cluster.sh`, `connect_to_k8.sh`, `apply_manifest.sh`, `rollout.sh` (replaced by Terraform + new scripts)

### Dev workflow
```bash
brew install podman terraform kind kubectl
podman machine init && podman machine start
cd terraform && terraform apply -var-file=dev.tfvars    # creates kind cluster
cd .. && ./scripts/build.sh dev                          # podman build + load into kind
./scripts/deploy.sh                                      # kubectl apply
kubectl port-forward -n mlops svc/frontend-app-service 8080:80
# Open http://localhost:8080
```

### Pros/Cons
- **Pro:** ~10 new files, familiar YAML, direct mapping from old scripts to new
- **Pro:** Fast to set up, easy to debug
- **Con:** No environment isolation in manifests (manual edits for dev vs prod)
- **Con:** Terraform only manages cluster, not K8s resources

---

## Option B: Industry Standard (Production-Grade)

**Philosophy:** Terraform modules + Helm charts + Ingress controller + container registry. Single `terraform apply` creates everything.

### Directory Structure
```
kubernetes/
├── backend/
│   ├── main.py                         # unchanged
│   ├── requirements.txt                # unchanged
│   └── Containerfile                   # renamed
├── frontend/
│   ├── index.html                      # fix: relative URL
│   ├── nginx.conf                      # fix: reverse proxy (mounted via ConfigMap)
│   ├── favicon.ico                     # unchanged
│   └── Containerfile                   # renamed, remove nginx.conf COPY
├── helm/
│   └── sum-calculator/
│       ├── Chart.yaml                  # chart metadata
│       ├── values.yaml                 # defaults (ClusterIP, 3 replicas)
│       ├── values-dev.yaml             # dev: 1 replica, no HPA, local registry
│       ├── values-prod.yaml            # prod: 3 replicas, HPA, GCR images
│       └── templates/
│           ├── _helpers.tpl
│           ├── namespace.yaml
│           ├── backend-deployment.yaml
│           ├── backend-service.yaml
│           ├── frontend-deployment.yaml
│           ├── frontend-service.yaml
│           ├── backend-hpa.yaml        # conditional on .Values.backend.hpa.enabled
│           ├── frontend-hpa.yaml       # conditional
│           ├── backend-networkpolicy.yaml  # port 8080, fixed
│           ├── ingress.yaml            # single ingress: / → frontend, /api/ → backend
│           └── frontend-configmap.yaml # nginx.conf as ConfigMap
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf                 # calls kind-cluster + app-deployment modules
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── terraform.tfvars
│   │   └── prod/
│   │       ├── main.tf                 # calls gke-cluster + container-registry + app-deployment
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── terraform.tfvars
│   │       └── backend.tf              # GCS remote state
│   └── modules/
│       ├── kind-cluster/               # local K8s via kind
│       ├── gke-cluster/                # GKE on GCP
│       ├── container-registry/         # local registry:2 (dev) or Artifact Registry (prod)
│       └── app-deployment/             # helm_release resource
├── scripts/
│   ├── build-and-push.sh              # podman build + push to registry
│   └── setup-dev.sh                    # full dev bootstrap including ingress-nginx
├── load_test.py                        # fix: env var
├── README.md
└── .gitignore
```

### Key differences from Option A
| Aspect | Option A | Option B |
|--------|----------|----------|
| K8s resource mgmt | `kubectl apply` (raw YAML) | Helm chart via Terraform `helm_release` |
| Service exposure (dev) | NodePort + port-forward | Ingress controller (nginx) |
| Service exposure (prod) | 2 LoadBalancers (2 IPs) | 1 Ingress (1 IP) |
| Container registry (dev) | `kind load` (no registry) | Local `registry:2` on localhost:5001 |
| Terraform structure | 5 flat files | ~15 files in modules + environments |
| Config management | Edit YAML directly | Helm values + ConfigMaps |
| New files | ~10 | ~30 |
| Time to understand | 1-2 hours | 4-8 hours |

### Dev workflow
```bash
brew install podman terraform kind kubectl helm
podman machine init && podman machine start
cd terraform/environments/dev && terraform apply          # cluster + registry + helm install
cd ../../.. && ./scripts/build-and-push.sh dev dev        # podman build + push to local registry
cd terraform/environments/dev && terraform apply          # re-apply with built images
# Access at http://localhost (kind ingress maps port 80)
```

### Pros/Cons
- **Pro:** Single `terraform apply` creates everything end-to-end
- **Pro:** Dev and prod are structurally identical (same Helm chart, different values)
- **Pro:** Reusable Terraform modules, CI/CD-ready, proper image tagging
- **Pro:** Single ingress IP instead of multiple LoadBalancers
- **Con:** ~30 new files, many new concepts simultaneously (Helm, modules, Ingress, ConfigMaps)
- **Con:** Harder to debug — is it Terraform, Helm, Ingress, or the app?

---

## Implementation Order (applies to whichever option is chosen)

1. **Fix hardcoded IPs** — `frontend/index.html` + `frontend/nginx.conf` reverse proxy
2. **Fix bugs** — network policy port, rollout.sh name
3. **Rename Dockerfiles → Containerfiles**, verify `podman build` works
4. **Set up Terraform** for local dev cluster (kind)
5. **Create build/deploy scripts** (Option A) or **Helm chart + Terraform modules** (Option B)
6. **Test full local workflow** end-to-end
7. **Add prod Terraform configuration** (GKE)
8. **Clean up** — delete old scripts and root-level test files
9. **Rewrite README** for new workflow

## Verification
- `podman build` both Containerfiles successfully
- `terraform apply` creates a kind cluster locally
- Images load/push to the cluster/registry
- `kubectl get pods -n mlops` shows all pods Running
- Open frontend in browser, enter two numbers, get correct sum back
- For prod: `terraform apply` creates GKE cluster, services get external IPs
