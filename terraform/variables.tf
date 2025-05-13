# --- variables.tf ---

variable "project_id" {
  description = "The GCP project ID to deploy resources into"
  type        = string
  # No default, should be provided in terraform.tfvars or as an environment variable
}

variable "region" {
  description = "The GCP region for the resources (e.g., us-central1)"
  type        = string
  default     = "us-central1" # Sensible default, can be overridden
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster (existing or to be created if not using data source)"
  type        = string
  # No default, should be provided in terraform.tfvars
}

variable "artifact_repo_name" {
  description = "The name for the Artifact Registry repository (existing or to be created if not using data source)"
  type        = string
  # No default, should be provided in terraform.tfvars
}

variable "node_count" {
  description = "The number of nodes in the GKE node pool"
  type        = number
  default     = 1 # Default node count, can be overridden
}

variable "node_machine_type" {
  description = "The machine type for the GKE nodes"
  type        = string
  default     = "n1-standard-8" # Default machine type, ensure this meets your needs and budget
}

# Add variables needed for the irmai-auth deployment
variable "auth_image_name" {
  description = "The name of the irmai-auth container image in Artifact Registry"
  type        = string
  # No default, should be provided in terraform.tfvars
}

variable "auth_image_tag" {
  description = "The tag for the irmai-auth container image"
  type        = string
  default     = "latest"
}

variable "auth_replica_count" {
  description = "The number of replicas for the irmai-auth deployment"
  type        = number
  default     = 1
}

variable "auth_container_port" {
  description = "The port the irmai-auth container listens on"
  type        = number
  default     = 8080 # Matches the targetPort in the service
}

