variable "environment" {
  description = "Deployment environment: dev or prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "sum-calculator-cluster"
}

# --- GKE-only variables (ignored when environment = dev) ---

variable "gcp_project" {
  description = "GCP project ID (required for prod)"
  type        = string
  default     = "k8s-podman-tf"
}

variable "gcp_region" {
  description = "GCP region for the GKE cluster"
  type        = string
  default     = "us-east1"
}

variable "gke_node_count" {
  description = "Number of nodes in the GKE cluster"
  type        = number
  default     = 1
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}
