#!/usr/bin/env bash
set -euo pipefail

# -e — exit immediately if any command fails
# -u — error on undefined variables (catches typos)
# -o pipefail — a pipe fails if any command in it fails, not just the last one

# Usage: 
# for dev: kind runs Kubernetes inside Docker/Podman containers. 
# Podman images live in Podman's image store, but kind's nodes can't see that.
# podman save — exports the image as a ".tar" archive
# kind load image-archive — import that tar directly into kind's nodes

ENV="${1:-dev}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SRC_DIR")"

echo "==> Building backend image..."
docker build --platform linux/amd64,linux/arm64 -t backend-app:latest "$REPO_ROOT/backend"

echo "==> Building frontend image..."
docker build --platform linux/amd64,linux/arm64 -t frontend-app:latest "$REPO_ROOT/frontend"

if [ "$ENV" = "dev" ]; then
    echo "==> Loading images into kind cluster..."
    kind load docker-image backend-app:latest --name sum-calculator-dev
    kind load docker-image frontend-app:latest --name sum-calculator-dev
    echo "==> Images loaded into kind."

elif [ "$ENV" = "prod" ]; then
    GCR_PREFIX="${GCR_PREFIX:-gcr.io/k8s-podman-tf}"
    TAG="${TAG:-v1}"
    echo "==> Tagging and pushing to $GCR_PREFIX..."
    docker tag backend-app:latest "$GCR_PREFIX/backend-app:$TAG"
    docker tag frontend-app:latest "$GCR_PREFIX/frontend-app:$TAG"
    docker push "$GCR_PREFIX/backend-app:$TAG"
    docker push "$GCR_PREFIX/frontend-app:$TAG"
    echo "==> Images pushed. Update k8s/ deployment YAMLs with:"
    echo "    image: $GCR_PREFIX/backend-app:$TAG"
    echo "    image: $GCR_PREFIX/frontend-app:$TAG"
else
    echo "Unknown environment: $ENV (use 'dev' or 'prod')"
    exit 1
fi
