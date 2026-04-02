#!/usr/bin/env bash
set -euo pipefail

# One-command local development bootstrap.
# Prerequisites: docker, terraform, kind, kubectl

#set pwd as repo root for easier path handling
REPO_ROOT="$(pwd)"

echo "=== Step 1: Create kind cluster via Terraform ==="
cd "$REPO_ROOT/terraform"
# terraform init
# For simplicity, we use -auto-approve here, but in a real setup you might want to review the plan first.
terraform apply -var-file=dev.tfvars -auto-approve

echo ""
echo "=== Step 2: Configure kubectl ==="
# kind export kubeconfig writes the cluster's kubeconfig to ~/.kube/config, merging with any existing contexts.
kind export kubeconfig --name sum-calculator-dev

echo ""
echo "=== Step 3: Build and load images ==="
"$REPO_ROOT/src/build_image.sh" dev

echo ""
echo "=== Step 4: Deploy to cluster ==="
"$REPO_ROOT/src/deploy_k8s.sh"

echo ""
echo "=== Setup complete! ==="
echo "Run this to access the app:"
echo "  kubectl port-forward -n k8s-adder svc/frontend-app-service 8080:80"
echo "Then open http://localhost:8080"
