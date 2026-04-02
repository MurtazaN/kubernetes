#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/deploy.sh

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
K8S_DIR="$(dirname "$SRC_DIR")/k8s"

echo "==> Creating namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

echo "==> Deploying backend..."
kubectl apply -f "$K8S_DIR/backend-deployment.yaml"
kubectl apply -f "$K8S_DIR/backend-service.yaml"

echo "==> Deploying frontend..."
kubectl apply -f "$K8S_DIR/frontend-deployment.yaml"
kubectl apply -f "$K8S_DIR/frontend-service.yaml"

echo "==> Applying HPAs..."
kubectl apply -f "$K8S_DIR/hpa/backend-hpa.yaml"
kubectl apply -f "$K8S_DIR/hpa/frontend-hpa.yaml"

echo "==> Applying network policies..."
kubectl apply -f "$K8S_DIR/network-policy/backend-access-policy.yaml"

echo "==> Waiting for rollout..."
kubectl rollout status deploy/backend-app -n k8s-adder --timeout=120s
kubectl rollout status deploy/frontend-app -n k8s-adder --timeout=120s

echo "==> All resources deployed. Pods:"
kubectl get pods -n k8s-adder
