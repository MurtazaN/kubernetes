terraform {
  required_version = "= 1.14.7"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ──────────────────────────────────────
# Local dev cluster (kind)
# ──────────────────────────────────────

provider "kind" {}

resource "kind_cluster" "dev" {
  count = var.environment == "dev" ? 1 : 0
  # TODO - attach "kind" in front of name to avoid conflicts with GKE cluster
  name  = var.cluster_name

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }
    node {
      role = "worker"
    }
  }
}

# ──────────────────────────────────────
# Production cluster (GKE)
# ──────────────────────────────────────

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

resource "google_container_cluster" "prod" {
  count    = var.environment == "prod" ? 1 : 0
  name     = var.cluster_name
  location = var.gcp_region

  initial_node_count       = var.gke_node_count
  remove_default_node_pool = false

  node_config {
    machine_type = var.gke_machine_type
    disk_size_gb = 50
    disk_type    = "pd-balanced"
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}
