# --- outputs.tf ---

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_node_pool_name" {
  description = "The name of the primary node pool"
  value       = google_container_node_pool.primary_nodes.name
}

# Updated output to construct the Artifact Registry URL manually
output "artifact_registry_url" {
  description = "The URL of the Artifact Registry Docker repository"
  # The URL format is [LOCATION]-docker.pkg.dev/[PROJECT_ID]/[REPOSITORY_ID]
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "kubernetes_namespace" {
  description = "The name of the Kubernetes namespace created"
  value       = kubernetes_namespace.outlier_demo.metadata[0].name
}

# This output for the LoadBalancer IP will be known only after apply
output "irmai_service_external_ip" {
  description = "The external IP address of the Irmai service LoadBalancer"
  # Use splat expression [*] in case ingress list is empty during plan
  value       = flatten(kubernetes_service.irmai_service.status[*].load_balancer[*].ingress[*].ip)[0]
}