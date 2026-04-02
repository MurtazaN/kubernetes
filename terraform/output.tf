output "cluster_name" {
  description = "Name of the created cluster"
  value       = var.cluster_name
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl"
  value = var.environment == "dev" ? (
    "kind export kubeconfig --name ${var.cluster_name}"
  ) : (
    "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.gcp_region} --project ${var.gcp_project}"
  )
}

output "environment" {
  description = "Current deployment environment"
  value       = var.environment
}
