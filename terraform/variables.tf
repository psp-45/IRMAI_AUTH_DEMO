# --- variables.tf ---

variable "project_id" {
  description = "The GCP project ID to deploy resources into"
  type        = string
}

variable "region" {
  description = "The GCP region for the resources (e.g., us-central1)"
  type        = string
  default     = "us-central1" # Example default
}

# Zone variable is not strictly needed for regional cluster config,
# but keep it if you need to specify zone for other resources or provider.
# variable "zone" {
#   description = "The GCP zone for zonal resources if needed (e.g., us-central1-c)"
#   type        = string
#   default     = "us-central1-c" # Example default
# }




variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "irmai-gke-cluster"
}

variable "artifact_repo_name" {
  description = "The name for the Artifact Registry repository"
  type        = string
  default     = "irmai-docker-repo"
}

variable "node_count" {
  description = "The number of nodes in the GKE node pool"
  type        = number
  default     = 2
}

variable "node_machine_type" {
  description = "The machine type for the GKE nodes"
  type        = string
  default     = "n1-standard-8" # Keep e2-medium or change if needed
}
