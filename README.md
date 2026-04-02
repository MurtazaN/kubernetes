# Kubernetes Microservices - Sum Calculator

## Overview

A microservices web application (FastAPI backend + Nginx frontend) deployed on Kubernetes. The frontend reverse-proxies API requests to the backend via cluster DNS — no hardcoded IPs.

**Infrastructure:** Docker for container builds, Terraform for cluster provisioning, supports local dev (kind) and production (GKE).

```
Browser → Nginx (frontend pod)
             ├── /           → serves index.html (static files)
             └── /api/add   → proxy_pass → backend-app-service (FastAPI pod)
                                             └── GET /add?a=X&b=Y → {"sum": Z}
```

---

## Project Structure

```
kubernetes/
├── backend/                         # FastAPI backend service
│   ├── main.py                      # GET /add endpoint
│   ├── requirements.txt             # fastapi, uvicorn
│   └── Dockerfile
├── frontend/                        # Nginx frontend service
│   ├── index.html                   # Web UI — calls /api/add (relative URL)
│   ├── nginx.conf                   # Serves static files + reverse proxies /api/ to backend
│   ├── favicon.ico
│   └── Dockerfile
├── k8s/                             # Kubernetes manifests
│   ├── namespace.yaml               # k8s-adder namespace
│   ├── backend-deployment.yaml      # 3 replicas, port 8080
│   ├── backend-service.yaml         # ClusterIP/LoadBalancer, port 80 → 8080
│   ├── frontend-deployment.yaml     # 3 replicas, port 80
│   ├── frontend-service.yaml        # LoadBalancer, port 80
│   ├── hpa/
│   │   ├── backend-hpa.yaml         # Autoscale 3–10 pods at 50% CPU
│   │   └── frontend-hpa.yaml
│   └── network-policy/
│       └── backend-access-policy.yaml  # Only frontend pods can reach backend on 8080
├── terraform/                       # Infrastructure as Code
│   ├── main.tf                      # kind (dev) or GKE (prod) via count conditional
│   ├── variables.tf                 # Inputs: environment, cluster_name, GCP settings
│   ├── output.tf                    # Prints kubeconfig command after apply
│   ├── dev.tfvars                   # Local kind cluster settings
│   └── prod.tfvars                  # GCP GKE settings
├── scripts/                         # Build and deploy automation
│   ├── build.sh                     # docker build + kind load (dev) / GCR push (prod)
│   ├── deploy.sh                    # kubectl apply all manifests in order
│   └── dev-setup.sh                 # One-command local bootstrap
├── load_test.py                     # Locust load testing (TARGET_HOST env var)
└── .gitignore
```

---

## Quick Start (Local Dev)

### Prerequisites

```bash
brew install --cask docker    # Docker Desktop
brew install terraform kind kubectl
```

### Option A: One command

```bash
./scripts/dev-setup.sh
```

### Option B: Step by step

```bash
# 1. Create kind cluster
cd terraform
terraform init
terraform apply -var-file=dev.tfvars
cd ..

# 2. Configure kubectl
kind export kubeconfig --name sum-calculator-dev

# 3. Build images with Docker and load into kind
./scripts/build.sh dev

# 4. Deploy all K8s resources
./scripts/deploy.sh

# 5. Access the app
kubectl port-forward -n k8s-adder svc/frontend-app-service 8080:80
# Open http://localhost:8080
```

---

## Production Deployment (GKE)

```bash
# 1. Create GKE cluster
cd terraform
terraform init
terraform apply -var-file=prod.tfvars
cd ..

# 2. Configure kubectl
gcloud container clusters get-credentials sum-calculator-prod \
  --region us-east1 --project k8s-podman-tf

# 3. Build and push images to GCR
./scripts/build.sh prod

# 4. Update image refs in k8s/ deployment YAMLs to gcr.io/... paths,
#    and set imagePullPolicy: Always

# 5. Deploy
./scripts/deploy.sh
```

---

## How It Works

### Frontend → Backend Communication

The browser sends all requests to the frontend Nginx pod. Nginx handles routing:

- **`/`** — serves `index.html` (static files)
- **`/api/*`** — reverse-proxied to the backend K8s service via cluster DNS:
  `backend-app-service.k8s-adder.svc.cluster.local:80`

The trailing `/` in `proxy_pass` strips the `/api/` prefix, so `/api/add?a=5&b=3` arrives at the backend as `/add?a=5&b=3`.

### Terraform Dev vs Prod

Both environments use the same `main.tf` with a `count` conditional:
- `environment = "dev"` → creates a local kind cluster (2 nodes)
- `environment = "prod"` → creates a GKE cluster on GCP

### Docker + kind Workflow

The build script:
1. `docker build` — builds the image locally
2. `kind load docker-image` — loads the image directly from Docker's store into kind's nodes

That's why deployments use `imagePullPolicy: IfNotPresent` for dev — the images are already on the node, no registry pull needed.

---

## Load Testing

```bash
pip install locust
TARGET_HOST=http://localhost:8080 locust -f load_test.py
```

---

## Notes

- **HPA** requires metrics-server in kind. Install it if you want autoscaling locally:
  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  ```
- **NetworkPolicy** requires a CNI that supports it (e.g., Calico). kind's default CNI (kindnet) does not enforce policies.
- **LoadBalancer** services stay in `Pending` state in kind — use `kubectl port-forward` instead.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Python 3.10, FastAPI, Uvicorn |
| Frontend | HTML5, JavaScript, Nginx |
| Containers | Docker |
| Orchestration | Kubernetes (kind for dev, GKE for prod) |
| Infrastructure | Terraform |
| Load Testing | Locust |
| Autoscaling | Kubernetes HPA (CPU-based) |
| Networking | K8s Services, NetworkPolicy, Nginx reverse proxy |
