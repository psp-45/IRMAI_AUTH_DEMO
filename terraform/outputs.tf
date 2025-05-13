# --- outputs.tf ---

output "gke_cluster_name" {
  description = "The name of the GKE cluster (fetched as data)"
  value       = data.google_container_cluster.primary.name
}

output "gke_node_pool_name" {
  description = "The name of the primary node pool. (Only valid if node pool resource is managed)"
  # If you removed the google_container_node_pool.primary_nodes resource, remove this output.
  value       = google_container_node_pool.primary_nodes.name
}

output "artifact_registry_url" {
  description = "The URL of the Artifact Registry Docker repository (fetched as data)"
  value       = "${data.google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.docker_repo.repository_id}"
}

output "irmai_auth_namespace_name" {
  description = "The name of the irmai-auth Kubernetes namespace"
  value       = kubernetes_namespace.irmai_auth.metadata[0].name
}

output "irmai_auth_service_external_ip" {
  description = "The external IP address of the irmai-auth-service LoadBalancer. May take a few minutes to become available."
  # Uses try() to prevent errors if the IP is not immediately available during 'terraform plan' or early 'apply'.
  # The value will be "pending" until the LoadBalancer is fully provisioned and has an IP.
  value       = try(kubernetes_service.irmai_auth_service.status[0].load_balancer[0].ingress[0].ip, "pending")
}
