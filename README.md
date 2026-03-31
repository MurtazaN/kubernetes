# Kubernetes Microservices - Sum Calculator

## Overview / Objective

This project demonstrates a **microservices-based web application** deployed on **Google Kubernetes Engine (GKE)**. It implements a simple sum calculator where a frontend web UI communicates with a backend API to perform addition. The project showcases core Kubernetes concepts including deployments, services, namespaces, horizontal pod autoscaling (HPA), network policies, and load balancing — serving as a hands-on lab for MLOps/Kubernetes fundamentals.

---

## Project Structure

```
kubernetes/
├── backend/                            # Backend microservice
│   ├── main.py                         # FastAPI application with /add endpoint
│   ├── requirements.txt                # Python dependencies (fastapi, uvicorn)
│   ├── Dockerfile                      # Container image for the backend
│   └── kubernetes/
│       ├── backend-deployment.yaml     # K8s Deployment (3 replicas)
│       └── backend-service.yaml        # K8s LoadBalancer Service
│
├── frontend/                           # Frontend microservice
│   ├── index.html                      # Web UI (HTML + JavaScript)
│   ├── nginx.conf                      # Nginx server configuration
│   ├── Dockerfile                      # Container image for the frontend
│   ├── favicon.ico                     # Site icon
│   └── kubernetes/
│       ├── frontend-deployment.yaml    # K8s Deployment (3 replicas)
│       └── frontend-service.yaml       # K8s LoadBalancer Service
│
├── kubernetes/
│   └── namespace.yaml                  # Namespace definition (mlops)
│
├── hpa/                                # Horizontal Pod Autoscaler configs
│   ├── backend-hpa.yaml               # Backend autoscaling (3–10 pods, 50% CPU)
│   └── frontend-hpa.yaml              # Frontend autoscaling (3–10 pods, 50% CPU)
│
├── network-policy/
│   └── backend-access-policy.yaml     # Restricts backend ingress to frontend only
│
├── Scripts/
│   ├── create_cluster.sh              # Creates GKE cluster on GCP
│   ├── apply_manifest.sh              # Deploys all K8s manifests in order
│   ├── connect_to_k8.sh              # Connects kubectl to the GKE cluster
│   └── rollout.sh                     # Checks deployment rollout status
│
├── main.py                            # Standalone FastAPI app (Hello World test)
├── Dockerfile                         # Dockerfile for the standalone app
├── requirements.txt                   # Dependencies for the standalone app
└── load_test.py                       # Locust-based load testing script
```

---

## Each Code File Objective

### Backend

| File | Purpose |
|------|---------|
| `backend/main.py` | FastAPI application exposing a `GET /add?a=<int>&b=<int>` endpoint that returns the sum of two integers. CORS is enabled for all origins. |
| `backend/requirements.txt` | Lists Python dependencies: `fastapi` and `uvicorn`. |
| `backend/Dockerfile` | Builds a Python 3.10 container image, installs dependencies, and runs Uvicorn on port 8080. |
| `backend/kubernetes/backend-deployment.yaml` | Kubernetes Deployment manifest — 3 replicas of the backend container with CPU/memory resource requests and limits. |
| `backend/kubernetes/backend-service.yaml` | Kubernetes Service (LoadBalancer) — exposes the backend externally on port 80, routing to container port 8080. |

### Frontend

| File | Purpose |
|------|---------|
| `frontend/index.html` | Static HTML page with two number inputs and a "Calculate Sum" button. JavaScript fetches the backend `/add` endpoint and displays the result. |
| `frontend/nginx.conf` | Nginx configuration — serves static files on port 80 with 404 fallback and suppressed favicon logging. |
| `frontend/Dockerfile` | Builds an `nginx:alpine` container image, copies the HTML and favicon into the Nginx document root. |
| `frontend/kubernetes/frontend-deployment.yaml` | Kubernetes Deployment manifest — 3 replicas of the frontend container with resource requests and limits. |
| `frontend/kubernetes/frontend-service.yaml` | Kubernetes Service (LoadBalancer) — exposes the frontend externally on port 80. |

### Kubernetes Configs

| File | Purpose |
|------|---------|
| `kubernetes/namespace.yaml` | Creates the `mlops` namespace to isolate all project resources. |
| `hpa/backend-hpa.yaml` | HorizontalPodAutoscaler for the backend — scales between 3 and 10 replicas when CPU exceeds 50%. Includes scale-up/down stabilization policies. |
| `hpa/frontend-hpa.yaml` | HorizontalPodAutoscaler for the frontend — same scaling rules as the backend HPA. |
| `network-policy/backend-access-policy.yaml` | NetworkPolicy restricting ingress to backend pods — only allows TCP/80 traffic from pods labeled `app: frontend-app`. |

### Scripts

| File | Purpose |
|------|---------|
| `Scripts/create_cluster.sh` | Creates a GKE cluster (`mlops-kubernetes-lab`) in `us-east1` with autoscaling, monitoring (Managed Prometheus), logging, and shielded nodes enabled. |
| `Scripts/apply_manifest.sh` | Applies all Kubernetes manifests in the correct order: namespace → backend → frontend → HPAs → network policy. |
| `Scripts/connect_to_k8.sh` | Authenticates kubectl with the GKE cluster and verifies the current context. |
| `Scripts/rollout.sh` | Checks the rollout status of deployments and lists running pods. |

### Root-Level Files

| File | Purpose |
|------|---------|
| `main.py` | Standalone FastAPI app returning `{"message": "Hello World GKE"}` — serves as a basic deployment test. |
| `Dockerfile` | Containerizes the root-level FastAPI app on port 8080. |
| `requirements.txt` | Dependencies for the root-level app (`fastapi`, `uvicorn`). |
| `load_test.py` | Locust load testing script — simulates concurrent users making GET requests to stress-test the deployed application. |

---

## App Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        User's Browser                            │
│  1. Opens frontend URL (LoadBalancer external IP)                │
│  2. index.html is served by Nginx                                │
│  3. User enters two numbers and clicks "Calculate Sum"           │
│  4. JavaScript sends GET request to backend LoadBalancer IP      │
│  5. Result is displayed on the page                              │
└──────────────────────┬───────────────────────────────────────────┘
                       │
          HTTP GET /add?a=X&b=Y
                       │
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│              Frontend Service (LoadBalancer :80)                  │
│              → Routes to Frontend Pods (Nginx)                   │
│              → Serves index.html to browser                      │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│              Backend Service (LoadBalancer :80 → :8080)           │
│              → Routes to one of 3 Backend Pods (FastAPI)         │
│              → /add endpoint computes sum                        │
│              → Returns JSON: {"sum": result}                     │
└──────────────────────────────────────────────────────────────────┘
```

The frontend and backend communicate over HTTP. The browser loads the frontend page, and client-side JavaScript directly calls the backend service's external IP to fetch computation results.

---

## Code Flow

### Backend (`backend/main.py`)
1. FastAPI app is created with CORS middleware allowing all origins.
2. `GET /add` endpoint receives query parameters `a` and `b` (integers).
3. Computes `a + b` and returns `{"sum": result}`.
4. Uvicorn serves the app on `0.0.0.0:8080`.

### Frontend (`frontend/index.html`)
1. HTML page renders two input fields and a submit button.
2. On button click, JavaScript reads input values.
3. A `fetch()` call is made to `http://<BACKEND_IP>/add?a=<val>&b=<val>`.
4. The JSON response is parsed and the sum is displayed in the UI.
5. Errors are caught and shown to the user.

### Kubernetes Orchestration
1. **Namespace** (`mlops`) isolates all resources.
2. **Deployments** maintain 3 replicas each for frontend and backend.
3. **Services** (LoadBalancer type) expose both services with external IPs.
4. **HPA** monitors CPU usage and scales pods between 3–10 replicas.
5. **NetworkPolicy** restricts backend ingress to only frontend pods (defense in depth).

### Load Testing (`load_test.py`)
1. Locust spawns simulated users.
2. Each user sends repeated GET requests to the target endpoint.
3. Responses are validated (HTTP 200) and failures are logged.

---

## Instructions to Setup and Run

### Prerequisites
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud` CLI)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/)
- A GCP project with billing enabled
- Python 3.10+ (for local testing)

### 1. Create the GKE Cluster

```bash
# Update the project ID and region in the script if needed
chmod +x Scripts/create_cluster.sh
./Scripts/create_cluster.sh
```

### 2. Connect to the Cluster

```bash
chmod +x Scripts/connect_to_k8.sh
./Scripts/connect_to_k8.sh
```

### 3. Deploy All Manifests

```bash
chmod +x Scripts/apply_manifest.sh
./Scripts/apply_manifest.sh
```

This applies resources in order: namespace → backend deployment & service → frontend deployment & service → HPAs → network policy.

### 4. Get External IPs

```bash
kubectl get services -n mlops
```

Wait until both services show an `EXTERNAL-IP` (may take 1–2 minutes). Note the backend's external IP.

### 5. Update Frontend with Backend IP

Edit `frontend/index.html` and replace the hardcoded backend IP in the `fetch()` URL with your backend service's external IP:

```javascript
const response = await fetch(`http://<YOUR_BACKEND_EXTERNAL_IP>/add?a=${a}&b=${b}`);
```

Then rebuild and redeploy the frontend image, or update the deployment to use the new image.

### 6. Access the Application

Open the **frontend service's external IP** in your browser. Enter two numbers and click "Calculate Sum".

### 7. Check Rollout Status

```bash
chmod +x Scripts/rollout.sh
./Scripts/rollout.sh
```

### 8. Run Load Tests (Optional)

```bash
pip install locust
python load_test.py
```

Update the target URL in `load_test.py` to your backend's external IP before running.

### Local Development (Without Kubernetes)

```bash
# Run the backend locally
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8080

# Serve the frontend locally (in another terminal)
cd frontend
python -m http.server 8000
# Open http://localhost:8000 in your browser
```

### Building Docker Images (Optional)

```bash
# Backend
docker build -t your-registry/backend-app:v1 ./backend
docker push your-registry/backend-app:v1

# Frontend
docker build -t your-registry/frontend-app:v1 ./frontend
docker push your-registry/frontend-app:v1
```

Update the image references in the Kubernetes deployment YAMLs to point to your own registry.

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Python 3.10, FastAPI, Uvicorn |
| Frontend | HTML5, CSS3, JavaScript, Nginx |
| Containerization | Docker |
| Orchestration | Kubernetes (GKE v1.31) |
| Cloud Provider | Google Cloud Platform |
| Monitoring | Managed Prometheus, GCP Cloud Logging |
| Load Testing | Locust (Python) |
| Autoscaling | Kubernetes HPA (CPU-based) |
| Networking | K8s LoadBalancer Services, NetworkPolicy |
