# Plan: Option A — Docker + Terraform (Simple)

## Context
Migrating the sum calculator microservice (FastAPI backend + Nginx frontend) from gcloud scripts to Terraform. Supports local dev (kind) and prod (GKE). User has already fixed 4/5 bugs. Remaining: nginx reverse proxy + new infra files.

**Why Docker instead of Podman:** The `tehcyx/kind` Terraform provider calls `docker info` directly and has no Podman support. Docker is required for the kind + Terraform workflow.

**User decisions:**
- Keep `Dockerfile` names
- Keep `k8s/hpa/` and `k8s/network-policy/` subfolder organization
- Use `/api/add` URL pattern (change index.html + add nginx proxy)
- Namespace stays `k8s-adder` (as existing manifests use)

---

## Step 1: Fix `frontend/index.html` — use `/api/add`
**File:** `frontend/index.html`
- Line 55: change `/add?a=...` → `/api/add?a=...`

## Step 2: Fix `frontend/nginx.conf` — add reverse proxy
**File:** `frontend/nginx.conf`
- Add `/api/` location block that proxies to `backend-app-service.k8s-adder.svc.cluster.local:80`
- The trailing `/` on proxy_pass strips the `/api/` prefix so the backend receives `/add?a=...`
- Add standard proxy headers (`Host`, `X-Real-IP`, `X-Forwarded-For`)

## Step 3: Update K8s deployment image refs for local dev
**Files:**
- `k8s/backend-deployment.yaml` (line 49): `murtazar/networking-backend-app:v1` → `backend-app:latest`, `imagePullPolicy: IfNotPresent`
- `k8s/frontend-deployment.yaml` (line 18): `murtazar/networking-frontend-app:v1` → `frontend-app:latest`, add `imagePullPolicy: IfNotPresent`

`IfNotPresent` is required for kind (images loaded locally, not from a registry).

## Step 4: Create `terraform/` directory (5 files)
- `variables.tf` — environment (dev/prod), cluster_name, GCP project/region/node config
- `main.tf` — `kind_cluster` resource (count = dev), `google_container_cluster` resource (count = prod)
- `outputs.tf` — cluster name, kubeconfig command (conditional on environment)
- `dev.tfvars` — `environment = "dev"`, `cluster_name = "sum-calculator-dev"`
- `prod.tfvars` — `environment = "prod"`, GCP project `kubernetes-labs-mlops`, region `us-east1` (from existing `src/create_cluster.sh`)

## Step 5: Create `scripts/` directory (3 files)
- `build.sh` — `docker build` both images; dev: `kind load docker-image`; prod: tag + push to GCR
- `deploy.sh` — `kubectl apply` manifests in order (namespace → deployments → services → HPAs → network policies), wait for rollout
- `dev-setup.sh` — one-command bootstrap: terraform init/apply → kind kubeconfig → build → deploy → print port-forward instructions

## Step 6: Update `.gitignore`
**File:** `.gitignore` (currently empty)
- Add: `__pycache__/`, `*.pyc`, `terraform/.terraform/`, `terraform/*.tfstate*`, `terraform/.terraform.lock.hcl`, `.DS_Store`, `*.tar`

## Step 7: Delete old files
- `main.py` (root) — unused hello world
- `Dockerfile` (root) — unused hello world
- `requirements.txt` (root) — was repurposed into a tool list, not valid pip file
- `src/` directory (all 4 scripts) — replaced by terraform + new scripts
- `__pycache__/` — should not be in repo
- `PLAN.md` — planning artifact, no longer needed

## Step 8: Rewrite `README.md`
- Project overview, architecture (Browser → Nginx → /api/ proxy → Backend)
- Prerequisites (docker, terraform, kind, kubectl)
- Quick start: `./src/dev-setup.sh` + `kubectl port-forward`
- Production deployment with prod.tfvars
- Updated directory tree

---

## Verification
1. `docker build` both Dockerfiles successfully
2. `terraform apply -var-file=dev.tfvars` creates a kind cluster
3. `./src/build_image.sh dev` loads images into kind
4. `./scripts/deploy.sh` — all pods reach Running state
5. `kubectl port-forward -n k8s-adder svc/frontend-app-service 8080:80`
6. Open `http://localhost:8080`, enter two numbers, get correct sum

## Notes
- HPA won't auto-scale in kind without metrics-server (document in README)
- NetworkPolicy won't enforce in kind without Calico (document in README)
- LoadBalancer services stay Pending in kind — port-forward is the dev workaround
